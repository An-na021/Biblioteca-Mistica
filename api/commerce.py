"""Atomic payment in game coins and delivery to the authenticated user's library."""

import time
import uuid

from .database import CatalogError, Database


class CommerceService:
    def __init__(self, database: Database, *, clock=time.time):
        self.database = database
        self.clock = clock

    @staticmethod
    def _payment(row):
        return {"id": row["id"], "reservation_id": row["reservation_id"], "amount": row["amount"],
                "balance": row["balance_after"], "status": "paid", "created_at": row["created_at"],
                "items": [{"book_id": row["book_id"], "quantity": row["quantity"]}]}

    def wallet(self, user_id):
        with self.database.connection() as connection:
            row = connection.execute("SELECT balance FROM wallets WHERE user_id = ?", (user_id,)).fetchone()
            if row is None:
                raise CatalogError(404, "Carteira não encontrada.")
            return {"balance": row["balance"]}

    def check_owner(self, reservation_id, user):
        with self.database.connection() as connection:
            if not connection.execute("SELECT 1 FROM reservations WHERE id = ?", (reservation_id,)).fetchone():
                raise CatalogError(404, "Reserva não encontrada.")
            owner = connection.execute("SELECT user_id FROM reservation_owners WHERE reservation_id = ?",
                                       (reservation_id,)).fetchone()
        if user["role"] != "admin" and (owner is None or owner["user_id"] != user["id"]):
            raise CatalogError(403, "Esta reserva pertence a outro usuário.")

    def checkout(self, user_id, reservation_id, idempotency_key):
        if not isinstance(idempotency_key, str) or not 1 <= len(idempotency_key.strip()) <= 150:
            raise CatalogError(422, "Informe uma chave de idempotência de até 150 caracteres.")
        with self.database.connection(write=True) as connection:
            existing = connection.execute("SELECT * FROM payments WHERE user_id = ? AND idempotency_key = ?",
                                          (user_id, idempotency_key)).fetchone()
            if existing is not None:
                if existing["reservation_id"] != reservation_id:
                    raise CatalogError(409, "Esta chave já foi usada em outra compra.")
                return self._payment(existing)
            reservation = connection.execute("SELECT * FROM reservations WHERE id = ?", (reservation_id,)).fetchone()
            if reservation is None:
                raise CatalogError(404, "Reserva não encontrada.")
            owner = connection.execute("SELECT user_id FROM reservation_owners WHERE reservation_id = ?",
                                       (reservation_id,)).fetchone()
            if owner is None or owner["user_id"] != user_id:
                raise CatalogError(403, "Esta reserva pertence a outro usuário.")
            if reservation["status"] != "active" or reservation["expires_at"] <= float(self.clock()):
                raise CatalogError(409, "A reserva não está ativa ou seu prazo terminou.")
            if connection.execute("SELECT 1 FROM payments WHERE reservation_id = ?", (reservation_id,)).fetchone():
                raise CatalogError(409, "Esta reserva já foi paga com outra chave.")
            book = connection.execute("SELECT sale_price FROM books WHERE id = ?", (reservation["book_id"],)).fetchone()
            if book is None:
                raise CatalogError(409, "O livro desta reserva não está mais disponível.")
            amount = book["sale_price"] * reservation["quantity"]
            debited = connection.execute("UPDATE wallets SET balance = balance - ? WHERE user_id = ? AND balance >= ?",
                                         (amount, user_id, amount)).rowcount
            if not debited:
                raise CatalogError(409, "Saldo de moedas insuficiente.")
            balance = connection.execute("SELECT balance FROM wallets WHERE user_id = ?", (user_id,)).fetchone()[0]
            connection.execute("UPDATE reservation_stock SET total = total - ?, reserved = reserved - ? WHERE book_id = ?",
                               (reservation["quantity"], reservation["quantity"], reservation["book_id"]))
            connection.execute("UPDATE reservations SET status = 'confirmed' WHERE id = ? AND status = 'active'",
                               (reservation_id,))
            connection.execute("INSERT INTO owned_books(user_id,book_id,quantity) VALUES (?, ?, ?) "
                               "ON CONFLICT(user_id,book_id) DO UPDATE SET quantity = quantity + excluded.quantity",
                               (user_id, reservation["book_id"], reservation["quantity"]))
            payment_id = uuid.uuid4().hex
            connection.execute("INSERT INTO payments(id,user_id,reservation_id,idempotency_key,book_id,quantity,amount,balance_after,created_at) "
                               "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
                               (payment_id, user_id, reservation_id, idempotency_key, reservation["book_id"],
                                reservation["quantity"], amount, balance, float(self.clock())))
            return self._payment(connection.execute("SELECT * FROM payments WHERE id = ?", (payment_id,)).fetchone())

    def library(self, user_id):
        with self.database.connection() as connection:
            return {"items": [dict(row) for row in connection.execute(
                "SELECT owned_books.book_id, owned_books.quantity, books.title, books.author FROM owned_books "
                "LEFT JOIN books ON books.id = owned_books.book_id WHERE user_id = ? ORDER BY owned_books.book_id", (user_id,))]}

    def payments(self, user_id):
        with self.database.connection() as connection:
            return {"items": [self._payment(row) for row in connection.execute(
                "SELECT * FROM payments WHERE user_id = ? ORDER BY created_at, id", (user_id,))]}

    def settings(self):
        with self.database.connection() as connection:
            row = dict(connection.execute("SELECT starting_money,shop_title,max_customers_per_day FROM app_settings WHERE id = 1").fetchone())
            return row

    def update_settings(self, changes):
        allowed = {"starting_money", "shop_title", "max_customers_per_day"}
        if not changes or not set(changes).issubset(allowed):
            raise CatalogError(422, "Informe ao menos uma configuração válida.")
        if "starting_money" in changes and (type(changes["starting_money"]) is not int or not 0 <= changes["starting_money"] <= 10000):
            raise CatalogError(422, "Saldo inicial inválido.")
        if "max_customers_per_day" in changes and (type(changes["max_customers_per_day"]) is not int or not 1 <= changes["max_customers_per_day"] <= 5):
            raise CatalogError(422, "O limite diário deve estar entre 1 e 5.")
        if "shop_title" in changes and (not isinstance(changes["shop_title"], str) or not 1 <= len(changes["shop_title"].strip()) <= 100):
            raise CatalogError(422, "Nome da livraria inválido.")
        if "shop_title" in changes:
            changes = {**changes, "shop_title": changes["shop_title"].strip()}
        with self.database.connection(write=True) as connection:
            connection.execute("UPDATE app_settings SET " + ",".join(f"{field} = ?" for field in changes) + " WHERE id = 1", list(changes.values()))
        return self.settings()
