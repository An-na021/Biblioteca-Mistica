"""Reservas temporárias: concorrência, prazo, recuperação e contrato HTTP."""

import tempfile
import threading
import unittest
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

from fastapi.testclient import TestClient

from api.database import CatalogError, Database
from api.main import create_app
from api.reservations import ReservationService


class Clock:
    def __init__(self, value=1_800_000_000.0):
        self.value = value

    def __call__(self):
        return self.value


class ReservationTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.path = Path(self.temporary.name) / "reservations.sqlite3"
        self.database = Database(self.path)
        self.database.initialize()
        self.clock = Clock()
        self.service = self.make_service()
        self.book = "jardim_horas"

    def tearDown(self):
        self.temporary.cleanup()

    def make_service(self, **options):
        return ReservationService(self.database, clock=self.clock, jitter_seconds=options.pop("jitter_seconds", 0), **options)

    def assert_error(self, status, function, *args):
        with self.assertRaises(CatalogError) as raised:
            function(*args)
        self.assertEqual(raised.exception.status, status)

    def test_reserve_cancel_is_idempotent_and_does_not_remove_stock(self):
        self.service.set_stock(self.book, 12)
        reservation = self.service.reserve(self.book, 3)
        self.assertEqual(reservation["status"], "active")
        self.assertEqual(reservation["expires_at"] - reservation["created_at"], 480)
        self.assertEqual(self.service.book_stock(self.book), {
            "book_id": self.book, "total": 12, "reserved": 3, "available": 9,
        })
        self.service.cancel(reservation["id"])
        self.service.cancel(reservation["id"])
        self.assertEqual(self.service.get(reservation["id"])["status"], "cancelled")
        self.assertEqual(self.service.book_stock(self.book)["available"], 12)

    def test_concurrent_reservations_never_oversell(self):
        self.service.set_stock(self.book, 25)
        barrier = threading.Barrier(8)

        def run(_):
            barrier.wait(timeout=10)
            successful = []
            for _ in range(10):
                try:
                    successful.append(self.service.reserve(self.book)["id"])
                except CatalogError as error:
                    self.assertEqual(error.status, 409)
            return successful

        with ThreadPoolExecutor(max_workers=8) as pool:
            reservations = [item for group in pool.map(run, range(8)) for item in group]
        self.assertEqual(len(reservations), 25)
        self.assertEqual(len(set(reservations)), 25)
        self.assertEqual(self.service.book_stock(self.book)["reserved"], 25)
        self.assertEqual(self.service.book_stock(self.book)["available"], 0)

    def test_separate_service_instances_share_atomic_stock(self):
        other = self.make_service()
        self.service.set_stock(self.book, 11)

        def reserve(index):
            try:
                return (self.service if index % 2 else other).reserve(self.book, 2)
            except CatalogError as error:
                self.assertEqual(error.status, 409)
                return None

        with ThreadPoolExecutor(max_workers=6) as pool:
            held = [item for item in pool.map(reserve, range(30)) if item]
        self.assertEqual(len(held), 5)
        self.assertEqual(self.service.book_stock(self.book)["reserved"], 10)
        self.assertEqual(other.book_stock(self.book)["available"], 1)

    def test_expiration_never_releases_early_and_is_idempotent(self):
        self.service.set_stock(self.book, 8)
        reservation = self.service.reserve(self.book, 3)
        self.clock.value = reservation["expires_at"] - 0.001
        self.service.process_due()
        self.assertEqual(self.service.book_stock(self.book)["reserved"], 3)
        self.clock.value = reservation["expires_at"]
        self.service.process_due()
        self.assertEqual(self.service.get(reservation["id"])["status"], "expired")
        for _ in range(4):
            self.service.process_due()
            self.service.cancel(reservation["id"])
        self.assertEqual(self.service.book_stock(self.book)["total"], 8)
        self.assertEqual(self.service.book_stock(self.book)["reserved"], 0)

    def test_jitter_is_bounded_and_keeps_all_eight_minutes(self):
        service = self.make_service(jitter_seconds=1)
        service.set_stock(self.book, 20)
        reservations = [service.reserve(self.book) for _ in range(15)]
        self.clock.value += 479.999
        service.process_due()
        self.assertEqual(service.book_stock(self.book)["reserved"], 15)
        self.clock.value += 1.002
        service.process_due()
        self.assertEqual(service.book_stock(self.book)["reserved"], 0)
        self.assertTrue(all(service.get(item["id"])["status"] == "expired" for item in reservations))

    def test_batches_eventually_release_each_reservation_once(self):
        service = self.make_service(batch_size=3)
        service.set_stock(self.book, 20)
        reservations = [service.reserve(self.book, 2) for _ in range(9)]
        self.clock.value += 480
        for _ in range(10):
            service.process_due()
        self.assertEqual(service.book_stock(self.book)["reserved"], 0)
        self.assertEqual(service.book_stock(self.book)["total"], 20)
        for reservation in reservations:
            self.assertEqual(service.get(reservation["id"])["status"], "expired")

    def test_restart_recovers_schedule_from_database(self):
        self.service.set_stock(self.book, 13)
        reservation = self.service.reserve(self.book, 4)
        recovered = self.make_service()
        self.clock.value += 479
        recovered.process_due()
        self.assertEqual(recovered.book_stock(self.book)["reserved"], 4)
        self.clock.value += 1
        recovered.process_due()
        self.assertEqual(recovered.book_stock(self.book)["available"], 13)
        self.assertEqual(recovered.get(reservation["id"])["status"], "expired")
        self.service.process_due()
        self.assertEqual(self.service.book_stock(self.book)["total"], 13)

    def test_discarded_cache_falls_back_to_database_and_can_be_rebuilt(self):
        reservation = self.service.reserve(self.book, 2)
        self.service.invalidate_cache()
        self.assertFalse(self.service.metrics()["cache_healthy"])
        self.clock.value += 480
        self.service.process_due()
        self.assertEqual(self.service.book_stock(self.book)["reserved"], 0)
        self.assertEqual(self.service.get(reservation["id"])["status"], "expired")
        fresh = self.service.reserve(self.book)
        self.assertEqual(self.service.rebuild_schedule(), 1)
        self.assertTrue(self.service.metrics()["cache_healthy"])
        self.clock.value += 480
        self.service.process_due()
        self.assertEqual(self.service.get(fresh["id"])["status"], "expired")

    def test_crash_between_mark_and_release_is_recovered_once(self):
        reservation = self.service.reserve(self.book, 3)
        self.clock.value += 480
        # Simula o estado durável depois do commit de marcação e antes da liberação.
        with self.database.connection(write=True) as connection:
            connection.execute("UPDATE reservations SET status = 'expired_pending_release' WHERE id = ?",
                               (reservation["id"],))
        recovered = self.make_service()
        recovered.process_due()
        self.service.process_due()
        self.assertEqual(recovered.book_stock(self.book)["total"], 10)
        self.assertEqual(recovered.book_stock(self.book)["reserved"], 0)
        self.assertEqual(recovered.metrics()["released_total"], 1)
        self.assertEqual(self.service.metrics()["released_total"], 0)

    def test_confirm_is_idempotent_and_consumes_exactly_once(self):
        self.service.set_stock(self.book, 10)
        reservation = self.service.reserve(self.book, 3)
        self.assertEqual(self.service.confirm(reservation["id"])["status"], "confirmed")
        self.assertEqual(self.service.confirm(reservation["id"])["status"], "confirmed")
        self.assertEqual(self.service.book_stock(self.book), {
            "book_id": self.book, "total": 7, "reserved": 0, "available": 7,
        })
        self.clock.value += 1000
        self.service.process_due()
        self.assertEqual(self.service.book_stock(self.book)["total"], 7)
        self.assert_error(409, self.service.cancel, reservation["id"])

    def test_expired_hold_cannot_be_confirmed_even_before_worker_runs(self):
        reservation = self.service.reserve(self.book)
        self.clock.value = reservation["expires_at"]
        self.assert_error(409, self.service.confirm, reservation["id"])
        self.assertEqual(self.service.get(reservation["id"])["status"], "expired")
        self.assertEqual(self.service.book_stock(self.book)["reserved"], 0)

    def test_stock_and_input_validation_preserve_existing_hold(self):
        self.service.set_stock(self.book, 5)
        reservation = self.service.reserve(self.book, 4)
        self.assert_error(409, self.service.set_stock, self.book, 3)
        self.assert_error(409, self.service.reserve, self.book, 2)
        self.assert_error(422, self.service.reserve, self.book, 0)
        self.assert_error(422, self.service.reserve, self.book, -1)
        self.assert_error(422, self.service.reserve, self.book, True)
        self.assert_error(422, self.service.set_stock, self.book, -1)
        self.assert_error(404, self.service.reserve, "nao_existe", 1)
        self.assert_error(404, self.service.get, "nao_existe")
        self.assertEqual(self.service.get(reservation["id"])["status"], "active")
        self.assertEqual(self.service.book_stock(self.book)["available"], 1)


class ReservationHttpTests(unittest.TestCase):
    def authorize_admin(self, client):
        auth = client.app.state.auth
        auth.create_user("admin_reservas", "SenhaDeTeste123", role="admin")
        token = auth.login("admin_reservas", "SenhaDeTeste123")["token"]
        client.headers.update({"Authorization": f"Bearer {token}"})

    def test_stock_reserve_confirm_and_cancel_routes(self):
        with tempfile.TemporaryDirectory() as temporary:
            with TestClient(create_app(Path(temporary) / "http.sqlite3")) as client:
                self.authorize_admin(client)
                response = client.put("/api/stock/jardim_horas", json={"total": 10})
                self.assertEqual(response.status_code, 200, response.text)
                response = client.post("/api/reservations", json={"book_id": "jardim_horas", "quantity": 2})
                self.assertEqual(response.status_code, 201, response.text)
                reservation = response.json()
                self.assertEqual(client.get(f"/api/reservations/{reservation['id']}").json()["status"], "active")
                self.assertEqual(client.post(f"/api/reservations/{reservation['id']}/confirm").status_code, 200)
                stock = client.get("/api/stock").json()["items"]
                row = next(item for item in stock if item["book_id"] == "jardim_horas")
                self.assertEqual(row["total"], 8)
                second = client.post("/api/reservations", json={"book_id": "jardim_horas", "quantity": 1}).json()
                self.assertEqual(client.delete(f"/api/reservations/{second['id']}").status_code, 204)
                self.assertEqual(client.delete(f"/api/reservations/{second['id']}").status_code, 204)
                self.assertEqual(client.post("/api/reservations", json={"book_id": "jardim_horas", "quantity": 0}).status_code, 422)
                self.assertEqual(client.put("/api/stock/jardim_horas", json={"total": -1}).status_code, 422)
                self.assertEqual(client.get("/api/reservations/inexistente").status_code, 404)

    def test_catalog_delete_cannot_destroy_reserved_stock(self):
        with tempfile.TemporaryDirectory() as temporary:
            with TestClient(create_app(Path(temporary) / "delete.sqlite3")) as client:
                self.authorize_admin(client)
                held = client.post("/api/reservations", json={"book_id": "relogio_perdido"}).json()
                self.assertEqual(client.delete("/api/books/relogio_perdido").status_code, 409)
                self.assertEqual(client.get(f"/api/reservations/{held['id']}").status_code, 200)
                self.assertEqual(client.delete(f"/api/reservations/{held['id']}").status_code, 204)
                self.assertEqual(client.delete("/api/books/relogio_perdido").status_code, 204)


if __name__ == "__main__":
    unittest.main()
