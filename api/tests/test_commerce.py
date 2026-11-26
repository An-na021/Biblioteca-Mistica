"""Conta local, autorização, moedas simuladas e checkout atômico."""

import tempfile
import unittest
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

from fastapi.testclient import TestClient

from api.main import create_app


class CommerceTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.path = Path(self.temporary.name) / "commerce.sqlite3"
        self.client = TestClient(create_app(self.path))
        self.client.__enter__()
        auth = self.client.app.state.auth
        auth.create_user("administrador", "SenhaDeTeste123", role="admin")
        self.admin = self.headers(auth.login("administrador", "SenhaDeTeste123"))
        self.player = self.register("jogador")
        self.other = self.register("outro_jogador")
        self.book = "jardim_horas"

    def tearDown(self):
        self.client.__exit__(None, None, None)
        self.temporary.cleanup()

    @staticmethod
    def headers(account):
        return {"Authorization": f"Bearer {account['token']}"}

    def register(self, username):
        response = self.client.post("/api/auth/register", json={"username": username, "password": "SenhaDeTeste123"})
        self.assertEqual(response.status_code, 201, response.text)
        return self.headers(response.json())

    def reserve(self, quantity=1, owner=None):
        response = self.client.post("/api/reservations", headers=owner or self.player,
                                    json={"book_id": self.book, "quantity": quantity})
        self.assertEqual(response.status_code, 201, response.text)
        return response.json()

    def checkout(self, reservation, key, headers=None):
        return self.client.post("/api/checkout", headers=headers or self.player,
                                json={"reservation_id": reservation["id"], "idempotency_key": key})

    def me(self, owner=None):
        response = self.client.get("/api/me", headers=owner or self.player)
        self.assertEqual(response.status_code, 200, response.text)
        return response.json()

    def test_register_login_logout_and_explicit_player_role(self):
        account = self.me()
        self.assertEqual(account["user"]["username"], "jogador")
        self.assertEqual(account["user"]["role"], "player")
        self.assertEqual(account["wallet"]["balance"], 100)
        duplicate = self.client.post("/api/auth/register", json={"username": "jogador", "password": "OutraSenha123"})
        self.assertEqual(duplicate.status_code, 409)
        short = self.client.post("/api/auth/register", json={"username": "curta", "password": "123"})
        self.assertEqual(short.status_code, 422)
        elevated = self.client.post("/api/auth/register", json={"username": "elevado", "password": "SenhaDeTeste123", "role": "admin"})
        self.assertEqual(elevated.status_code, 422)
        invalid = self.client.post("/api/auth/login", json={"username": "jogador", "password": "incorreta123"})
        self.assertEqual(invalid.status_code, 401)
        login = self.client.post("/api/auth/login", json={"username": "jogador", "password": "SenhaDeTeste123"})
        self.assertEqual(login.status_code, 200, login.text)
        self.assertNotIn("password", login.json()["user"])
        active_headers = self.headers(login.json())
        self.assertEqual(self.client.get("/api/me", headers=active_headers).status_code, 200)
        self.assertEqual(self.client.post("/api/auth/logout", headers=active_headers).status_code, 204)
        self.assertEqual(self.client.get("/api/me", headers=active_headers).status_code, 401)

    def test_authentication_and_administrator_boundaries(self):
        self.assertEqual(self.client.get("/api/me").status_code, 401)
        self.assertEqual(self.client.get("/api/me", headers={"Authorization": "Bearer invalido"}).status_code, 401)
        self.assertEqual(self.client.post("/api/reservations", json={"book_id": self.book}).status_code, 401)
        self.assertEqual(self.client.patch("/api/settings", headers=self.player, json={"starting_money": 250}).status_code, 403)
        self.assertEqual(self.client.put(f"/api/stock/{self.book}", headers=self.player, json={"total": 20}).status_code, 403)
        self.assertEqual(self.client.patch(f"/api/books/{self.book}", headers=self.player, json={"sale_price": 20}).status_code, 403)
        self.assertEqual(self.client.delete(f"/api/books/{self.book}", headers=self.player).status_code, 403)
        sample = self.client.get(f"/api/books/{self.book}").json()
        self.assertEqual(self.client.post("/api/books", json={**sample, "id": "sem_autorizacao"}).status_code, 401)
        held = self.reserve()
        self.assertEqual(self.client.post(f"/api/reservations/{held['id']}/confirm", headers=self.player).status_code, 403)

    def test_admin_settings_apply_to_new_wallet_without_resetting_existing(self):
        response = self.client.patch("/api/settings", headers=self.admin, json={
            "starting_money": 175, "shop_title": "Livraria de testes", "max_customers_per_day": 4,
        })
        self.assertEqual(response.status_code, 200, response.text)
        self.assertEqual(response.json()["starting_money"], 175)
        self.assertEqual(response.json()["shop_title"], "Livraria de testes")
        self.assertEqual(self.me()["wallet"]["balance"], 100)
        newcomer = self.register("novo_saldo")
        self.assertEqual(self.me(newcomer)["wallet"]["balance"], 175)
        invalid = self.client.patch("/api/settings", headers=self.admin, json={"starting_money": -1})
        self.assertEqual(invalid.status_code, 422)

    def test_payment_uses_server_price_and_is_idempotent(self):
        self.client.put(f"/api/stock/{self.book}", headers=self.admin, json={"total": 10})
        price = self.client.get(f"/api/books/{self.book}").json()["sale_price"]
        held = self.reserve(2)
        response = self.checkout(held, "compra-001")
        self.assertEqual(response.status_code, 200, response.text)
        payment = response.json()
        self.assertEqual(payment["status"], "paid")
        self.assertEqual(payment["amount"], 2 * price)
        self.assertEqual(payment["balance"], 100 - 2 * price)
        repeated = self.checkout(held, "compra-001")
        self.assertEqual(repeated.status_code, 200, repeated.text)
        self.assertEqual(repeated.json()["id"], payment["id"])
        self.assertEqual(self.me()["wallet"]["balance"], 100 - 2 * price)
        library = self.client.get("/api/library", headers=self.player).json()["items"]
        owned = next(item for item in library if item["book_id"] == self.book)
        self.assertEqual(owned["quantity"], 2)
        payments = self.client.get("/api/payments", headers=self.player).json()["items"]
        self.assertEqual(len(payments), 1)
        self.assertEqual(self.checkout(held, "segunda-chave").status_code, 409)
        stock = next(item for item in self.client.get("/api/stock").json()["items"] if item["book_id"] == self.book)
        self.assertEqual(stock["total"], 8)
        self.assertEqual(stock["reserved"], 0)

    def test_owner_protection_prevents_read_cancel_and_checkout_from_another_account(self):
        held = self.reserve()
        endpoint = f"/api/reservations/{held['id']}"
        self.assertEqual(self.client.get(endpoint, headers=self.other).status_code, 403)
        self.assertEqual(self.client.delete(endpoint, headers=self.other).status_code, 403)
        self.assertEqual(self.checkout(held, "roubo", headers=self.other).status_code, 403)
        self.assertEqual(self.client.get(endpoint, headers=self.player).json()["status"], "active")
        self.assertEqual(self.client.get(endpoint, headers=self.admin).status_code, 200)
        self.assertEqual(self.me()["wallet"]["balance"], 100)
        self.assertEqual(self.client.get("/api/library", headers=self.other).json()["items"], [])

    def test_insufficient_funds_roll_back_every_payment_effect(self):
        self.client.put(f"/api/stock/{self.book}", headers=self.admin, json={"total": 100})
        held = self.reserve(100)
        response = self.checkout(held, "sem-saldo")
        self.assertEqual(response.status_code, 409, response.text)
        self.assertEqual(self.me()["wallet"]["balance"], 100)
        self.assertEqual(self.client.get("/api/library", headers=self.player).json()["items"], [])
        self.assertEqual(self.client.get("/api/payments", headers=self.player).json()["items"], [])
        self.assertEqual(self.client.get(f"/api/reservations/{held['id']}", headers=self.player).json()["status"], "active")

    def test_expired_hold_and_client_price_override_are_rejected(self):
        held = self.reserve()
        manipulated = self.client.post("/api/checkout", headers=self.player, json={
            "reservation_id": held["id"], "idempotency_key": "preco-adulterado", "amount": 0,
        })
        self.assertEqual(manipulated.status_code, 422)
        self.client.app.state.reservations.clock = lambda: held["expires_at"] + 1
        self.client.app.state.commerce.clock = lambda: held["expires_at"] + 1
        expired = self.checkout(held, "fora-prazo")
        self.assertEqual(expired.status_code, 409, expired.text)
        self.assertEqual(self.me()["wallet"]["balance"], 100)
        self.assertEqual(self.client.get("/api/library", headers=self.player).json()["items"], [])

    def test_concurrent_checkout_retries_debit_only_once(self):
        held = self.reserve()
        price = self.client.get(f"/api/books/{self.book}").json()["sale_price"]

        def pay(_):
            return self.checkout(held, "chave-concorrente")

        with ThreadPoolExecutor(max_workers=4) as pool:
            responses = list(pool.map(pay, range(4)))
        self.assertEqual([response.status_code for response in responses], [200] * 4)
        self.assertEqual(len({response.json()["id"] for response in responses}), 1)
        self.assertEqual(self.me()["wallet"]["balance"], 100 - price)
        self.assertEqual(len(self.client.get("/api/payments", headers=self.player).json()["items"]), 1)

    def test_password_salts_and_session_tokens_are_not_stored_in_plaintext(self):
        auth = self.client.app.state.auth
        login = auth.login("jogador", "SenhaDeTeste123")
        with self.client.app.state.database.connection() as connection:
            users = list(connection.execute("SELECT password_salt,password_hash FROM users WHERE role = 'player'"))
            session_hashes = [row[0] for row in connection.execute("SELECT token_hash FROM sessions")]
        self.assertEqual(len(users), 2)
        self.assertNotEqual(users[0]["password_salt"], users[1]["password_salt"])
        self.assertNotEqual(users[0]["password_hash"], users[1]["password_hash"])
        self.assertTrue(all(row["password_hash"] != "SenhaDeTeste123" for row in users))
        self.assertNotIn(login["token"], session_hashes)

    def test_session_expiration_is_enforced(self):
        auth = self.client.app.state.auth
        login = auth.login("jogador", "SenhaDeTeste123")
        auth.clock = lambda: login["expires_at"]
        self.assertEqual(self.client.get("/api/me", headers=self.headers(login)).status_code, 401)


if __name__ == "__main__":
    unittest.main()
