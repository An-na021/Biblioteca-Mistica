import copy
import sqlite3
import tempfile
import unittest
from concurrent.futures import ThreadPoolExecutor
from contextlib import closing
from pathlib import Path

from fastapi.testclient import TestClient

from api.main import create_app


class ApiTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.path = Path(self.temporary.name) / "test.sqlite3"
        self.app = create_app(self.path)
        self.client = TestClient(self.app)
        self.client.__enter__()

    def tearDown(self):
        self.client.__exit__(None, None, None)
        self.temporary.cleanup()

    def sample(self, resource):
        record = copy.deepcopy(self.client.get(f"/api/{resource}").json()["items"][0])
        record["id"] = "teste_novo"
        return record

    def test_seed_health_and_openapi(self):
        self.assertEqual(self.client.get("/api/health").json()["status"], "ok")
        catalog = self.client.get("/api/catalog").json()
        self.assertEqual([len(catalog[key]) for key in ["books", "customers", "suppliers"]], [8, 8, 3])
        self.assertEqual(self.client.get("/docs").status_code, 200)
        spec = self.client.get("/openapi.json").json()
        for resource in ["books", "customers", "suppliers"]:
            self.assertIn("post", spec["paths"][f"/api/{resource}"])
            self.assertEqual(set(spec["paths"][f"/api/{resource}/{{record_id}}"]), {"get", "put", "patch", "delete"})

    def test_crud_of_all_three_resources(self):
        for resource in ["books", "customers", "suppliers"]:
            with self.subTest(resource=resource):
                payload = self.sample(resource)
                endpoint = f"/api/{resource}"
                record_url = endpoint + "/" + payload["id"]
                created = self.client.post(endpoint, json=payload)
                self.assertEqual(created.status_code, 201, created.text)
                self.assertEqual(created.headers["location"], record_url)
                self.assertEqual(self.client.get(record_url).json()["id"], payload["id"])
                self.assertEqual(self.client.post(endpoint, json=payload).status_code, 409)
                field = "title" if resource == "books" else "name"
                text = "Edição d'Água; DROP TABLE books;--"
                changed = self.client.patch(record_url, json={field: text})
                self.assertEqual(changed.status_code, 200, changed.text)
                self.assertEqual(changed.json()[field], text)
                self.assertEqual(self.client.get(endpoint, params={"q": "EDICAO D'AGUA"}).json()["total"], 1)
                payload[field] = "Registro substituído"
                self.assertEqual(self.client.put(record_url, json=payload).status_code, 200)
                self.assertEqual(self.client.get(record_url).json()[field], payload[field])
                self.assertEqual(self.client.delete(record_url).status_code, 204)
                self.assertEqual(self.client.get(record_url).status_code, 404)
                self.assertEqual(self.client.delete(record_url).status_code, 404)
        self.assertEqual(self.client.get("/api/books").json()["total"], 8)

    def test_validation_and_immutable_identifiers(self):
        payload = self.sample("books")
        for price in [-1, 0, 1.5, True, "8"]:
            with self.subTest(price=price):
                self.assertEqual(self.client.post("/api/books", json={**payload, "sale_price": price}).status_code, 422)
        self.assertEqual(self.client.post("/api/books", json={**payload, "title": "  "}).status_code, 422)
        self.assertEqual(self.client.post("/api/books", json={**payload, "tags": ["magia", "magia"]}).status_code, 422)
        self.assertEqual(self.client.post("/api/books", json={**payload, "district_ids": ["inexistente"]}).status_code, 422)
        self.assertEqual(self.client.patch("/api/books/jardim_horas", json={"id": "outro"}).status_code, 422)
        self.assertEqual(self.client.patch("/api/books/jardim_horas", json={"title": None}).status_code, 422)
        self.assertEqual(self.client.patch("/api/books/jardim_horas", json={}).status_code, 422)
        self.assertEqual(self.client.put("/api/books/jardim_horas", json=payload).status_code, 409)
        self.assertEqual(self.client.put("/api/books/jardim_horas", json={"title": "Incompleto"}).status_code, 422)
        for resource in ["books", "customers", "suppliers"]:
            self.assertEqual(self.client.get(f"/api/{resource}", params={"limit": 0}).status_code, 422)

    def test_prices_risk_scenes_and_assets(self):
        supplier = self.sample("suppliers")
        for risk in [-0.1, 1.1]:
            self.assertEqual(self.client.post("/api/suppliers", json={**supplier, "risk": risk}).status_code, 422)
        customer = self.sample("customers")
        self.assertEqual(self.client.post("/api/customers", json={**customer, "scene_path": "res://scripts/main_game.gd"}).status_code, 422)
        book = self.sample("books")
        for path in ["C:/secret.png", "res://bookimg/../icon.svg", "res://bookimg/missing.png"]:
            self.assertEqual(self.client.post("/api/books", json={**book, "cover_path": path}).status_code, 422)

    def test_filters_and_pagination(self):
        result = self.client.get("/api/books", params={"district": "minas", "tag": "mapas", "limit": 1}).json()
        self.assertEqual(result["total"], 2)
        self.assertEqual(len(result["items"]), 1)
        next_page = self.client.get("/api/books", params={"district": "minas", "tag": "mapas", "limit": 1, "offset": 1}).json()
        self.assertNotEqual(result["items"][0]["id"], next_page["items"][0]["id"])
        self.assertEqual(self.client.get("/api/books", params={"q": "%_'; DROP TABLE books;--"}).json()["total"], 0)

    def test_failed_mutation_rolls_back_related_records(self):
        book = {**self.sample("books"), "id": "tema_exclusivo", "tags": ["exclusivo"], "district_ids": ["centro"]}
        self.assertEqual(self.client.post("/api/books", json=book).status_code, 201)
        customer = {**self.sample("customers"), "id": "leitor_exclusivo", "preference_tags": ["exclusivo"], "district_ids": ["centro"]}
        self.assertEqual(self.client.post("/api/customers", json=customer).status_code, 201)
        self.assertEqual(self.client.delete("/api/books/tema_exclusivo").status_code, 409)
        self.assertEqual(self.client.get("/api/books/tema_exclusivo").json()["tags"], ["exclusivo"])
        self.assertEqual(self.client.patch("/api/books/tema_exclusivo", json={"tags": ["outro"]}).status_code, 409)
        self.assertEqual(self.client.get("/api/books/tema_exclusivo").json()["tags"], ["exclusivo"])
        self.assertEqual(self.client.delete("/api/customers/leitor_exclusivo").status_code, 204)
        self.assertEqual(self.client.delete("/api/books/tema_exclusivo").status_code, 204)
        with closing(sqlite3.connect(self.path)) as connection:
            self.assertEqual(connection.execute("SELECT count(*) FROM book_districts WHERE book_id = ?", ("tema_exclusivo",)).fetchone()[0], 0)
            self.assertFalse(connection.execute("PRAGMA foreign_key_check").fetchall())

    def test_special_order_provider_can_be_replaced(self):
        self.assertEqual(self.client.delete("/api/suppliers/praca").status_code, 409)
        supplier = {**self.sample("suppliers"), "special_orders": True}
        self.assertEqual(self.client.post("/api/suppliers", json=supplier).status_code, 201)
        self.assertEqual(self.client.delete("/api/suppliers/praca").status_code, 204)

    def test_restart_does_not_reseed_edited_or_deleted_data(self):
        self.assertEqual(self.client.patch("/api/books/jardim_horas", json={"sale_price": 17}).status_code, 200)
        self.assertEqual(self.client.delete("/api/books/relogio_perdido").status_code, 204)
        with TestClient(create_app(self.path)) as restarted:
            self.assertEqual(restarted.get("/api/books/jardim_horas").json()["sale_price"], 17)
            self.assertEqual(restarted.get("/api/books/relogio_perdido").status_code, 404)
            self.assertEqual(restarted.get("/api/books").json()["total"], 7)

    def test_concurrent_writes_remain_consistent(self):
        sample = self.sample("books")
        def create(index):
            return self.client.post("/api/books", json={**sample, "id": f"paralelo_{index}"}).status_code
        with ThreadPoolExecutor(max_workers=4) as pool:
            self.assertEqual(list(pool.map(create, range(8))), [201] * 8)
        self.assertEqual(self.client.get("/api/books").json()["total"], 16)


if __name__ == "__main__":
    unittest.main()
