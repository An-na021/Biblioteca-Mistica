"""Temporary stock holds, with durable two-phase expiration and a disposable cache.

The SQLite transaction owns stock consistency. The heap is only an acceleration
index: it may be rebuilt or discarded without losing a hold or returning it twice.
This stock deliberately does not change the inventory or orders in Godot saves.
"""

import heapq
import logging
import math
import random
import threading
import time
import uuid
from collections import Counter

from .database import CatalogError, Database

LOGGER = logging.getLogger(__name__)


class ReservationService:
    DEFAULT_STOCK = 10

    def __init__(self, database: Database, *, clock=time.time, ttl_seconds=480,
                 jitter_seconds=1, batch_size=1024, poll_seconds=0.1):
        if not math.isfinite(ttl_seconds) or ttl_seconds <= 0:
            raise ValueError("ttl_seconds must be positive and finite")
        if not math.isfinite(jitter_seconds) or not 0 <= jitter_seconds <= 1:
            raise ValueError("jitter_seconds must be between zero and one")
        if type(batch_size) is not int or batch_size < 1:
            raise ValueError("batch_size must be a positive integer")
        if not math.isfinite(poll_seconds) or poll_seconds <= 0:
            raise ValueError("poll_seconds must be positive and finite")
        self.database = database
        self.clock = clock
        self.ttl_seconds = float(ttl_seconds)
        self.jitter_seconds = float(jitter_seconds)
        self.batch_size = batch_size
        self.poll_seconds = float(poll_seconds)
        self._lock = threading.RLock()
        self._schedule = []
        self._cache_healthy = True
        self._last_sweep = float("-inf")
        self._stop = threading.Event()
        self._worker = None
        self._counters = {"marked_total": 0, "released_total": 0, "mark_batches": 0,
                          "release_batches": 0, "cache_recoveries": 0,
                          "last_process_duration_seconds": 0.0,
                          "max_release_lag_seconds": 0.0, "worker_errors": 0}

    def start(self):
        with self._lock:
            if self._worker is not None and self._worker.is_alive():
                return
            self.rebuild_schedule()
            self._stop.clear()
            self._worker = threading.Thread(target=self._run, name="biblioteca-reservations", daemon=True)
            self._worker.start()

    def stop(self):
        self._stop.set()
        worker = self._worker
        if worker is not None and worker is not threading.current_thread():
            worker.join(timeout=10)
        self._worker = None

    def _run(self):
        while not self._stop.is_set():
            try:
                self.process_due(collect_metrics=False)
            except Exception:
                with self._lock:
                    self._counters["worker_errors"] += 1
                    self.invalidate_cache()
                LOGGER.exception("Reservation expiration failed; durable pending work will be retried")
            self._stop.wait(self.poll_seconds)

    def rebuild_schedule(self):
        """Recover the disposable deadline index after a restart or cache failure."""
        with self._lock, self.database.connection() as connection:
            self._schedule = [(row["release_after"], row["id"]) for row in connection.execute(
                "SELECT id, release_after FROM reservations WHERE status = 'active'")]
            heapq.heapify(self._schedule)
            self._cache_healthy = True
            self._last_sweep = float("-inf")
            self._counters["cache_recoveries"] += 1
            return len(self._schedule)

    def invalidate_cache(self):
        """Continue using indexed database sweeps until the cache is rebuilt."""
        with self._lock:
            self._schedule.clear()
            self._cache_healthy = False
            self._last_sweep = float("-inf")

    @staticmethod
    def _positive_quantity(value):
        if type(value) is not int or value < 1:
            raise CatalogError(422, "A quantidade deve ser um inteiro positivo.")

    def _ensure_stock(self, connection, book_id):
        if not connection.execute("SELECT 1 FROM books WHERE id = ?", (book_id,)).fetchone():
            raise CatalogError(404, "Livro não encontrado.")
        connection.execute("INSERT OR IGNORE INTO reservation_stock(book_id, total, reserved) VALUES (?, ?, 0)",
                           (book_id, self.DEFAULT_STOCK))

    @staticmethod
    def _stock(connection, book_id):
        row = connection.execute("SELECT book_id, total, reserved, total - reserved AS available "
                                 "FROM reservation_stock WHERE book_id = ?", (book_id,)).fetchone()
        return dict(row)

    def book_stock(self, book_id=None):
        # SQLite WAL readers need not wait for the worker's cache lock.
        with self.database.connection() as connection:
            if book_id is not None:
                row = connection.execute("SELECT books.id AS book_id, coalesce(s.total, ?) AS total, "
                    "coalesce(s.reserved, 0) AS reserved, coalesce(s.total, ?) - coalesce(s.reserved, 0) AS available "
                    "FROM books LEFT JOIN reservation_stock s ON s.book_id = books.id WHERE books.id = ?",
                    (self.DEFAULT_STOCK, self.DEFAULT_STOCK, book_id)).fetchone()
                if row is None:
                    raise CatalogError(404, "Livro não encontrado.")
                return dict(row)
            return {"items": [dict(row) for row in connection.execute(
                "SELECT books.id AS book_id, coalesce(s.total, ?) AS total, coalesce(s.reserved, 0) AS reserved, "
                "coalesce(s.total, ?) - coalesce(s.reserved, 0) AS available "
                "FROM books LEFT JOIN reservation_stock s ON s.book_id = books.id ORDER BY books.id",
                (self.DEFAULT_STOCK, self.DEFAULT_STOCK))]}

    def set_stock(self, book_id, total):
        if type(total) is not int or total < 0:
            raise CatalogError(422, "O estoque total deve ser um inteiro não negativo.")
        with self.database.connection(write=True) as connection:
            self._ensure_stock(connection, book_id)
            if total < self._stock(connection, book_id)["reserved"]:
                raise CatalogError(409, "O estoque total não pode ser menor que a quantidade reservada.")
            connection.execute("UPDATE reservation_stock SET total = ? WHERE book_id = ?", (total, book_id))
            return self._stock(connection, book_id)

    @staticmethod
    def _row(connection, reservation_id):
        row = connection.execute("SELECT * FROM reservations WHERE id = ?", (reservation_id,)).fetchone()
        if row is None:
            raise CatalogError(404, "Reserva não encontrada.")
        return dict(row)

    @staticmethod
    def _public(row):
        return {"id": row["id"], "book_id": row["book_id"], "quantity": row["quantity"],
                "status": "expired" if row["status"] == "expired_pending_release" else row["status"],
                "created_at": row["created_at"], "expires_at": row["expires_at"]}

    def reserve(self, book_id, quantity=1, *, owner_id=None):
        self._positive_quantity(quantity)
        now = float(self.clock())
        reservation_id = uuid.uuid4().hex
        expires_at = now + self.ttl_seconds
        release_after = expires_at + random.uniform(0, self.jitter_seconds)
        with self.database.connection(write=True) as connection:
            self._ensure_stock(connection, book_id)
            changed = connection.execute("UPDATE reservation_stock SET reserved = reserved + ? "
                "WHERE book_id = ? AND total - reserved >= ?", (quantity, book_id, quantity)).rowcount
            if not changed:
                raise CatalogError(409, "Exemplares disponíveis insuficientes.")
            connection.execute("INSERT INTO reservations(id,book_id,quantity,status,created_at,expires_at,release_after) "
                "VALUES (?, ?, ?, 'active', ?, ?, ?)",
                (reservation_id, book_id, quantity, now, expires_at, release_after))
            if owner_id is not None:
                connection.execute("INSERT INTO reservation_owners(reservation_id,user_id) VALUES (?, ?)",
                                   (reservation_id, owner_id))
            result = self._public(self._row(connection, reservation_id))
        with self._lock:
            if self._cache_healthy:
                heapq.heappush(self._schedule, (release_after, reservation_id))
        return result

    def _expire_on_access(self, reservation_id, now):
        # Marking and stock release intentionally commit in separate transactions.
        with self.database.connection() as connection:
            row = self._row(connection, reservation_id)
        if row["status"] == "expired_pending_release":
            self._release_pending(now)
            return
        if row["status"] != "active" or row["expires_at"] > now:
            return
        with self.database.connection(write=True) as connection:
            row = self._row(connection, reservation_id)
            expired = row["status"] == "active" and row["expires_at"] <= now
            if expired:
                connection.execute("UPDATE reservations SET status = 'expired_pending_release' WHERE id = ? AND status = 'active'",
                                   (reservation_id,))
        if expired:
            with self._lock:
                self._counters["marked_total"] += 1
                self._counters["mark_batches"] += 1
        if expired or row["status"] == "expired_pending_release":
            self._release_pending(now)

    def get(self, reservation_id):
        self._expire_on_access(reservation_id, float(self.clock()))
        with self.database.connection() as connection:
            return self._public(self._row(connection, reservation_id))

    def confirm(self, reservation_id):
        # Read and mutate under the same SQLite writer transaction. The cache
        # mutex protects only memory; it never serializes request disk I/O.
        with self.database.connection(write=True) as connection:
            now = float(self.clock())
            row = self._row(connection, reservation_id)
            if row["status"] == "confirmed":
                return self._public(row)
            if row["status"] == "active" and row["expires_at"] > now:
                connection.execute("UPDATE reservation_stock SET total = total - ?, reserved = reserved - ? WHERE book_id = ?",
                                   (row["quantity"], row["quantity"], row["book_id"]))
                connection.execute("UPDATE reservations SET status = 'confirmed' WHERE id = ?", (reservation_id,))
                return self._public(self._row(connection, reservation_id))
            marked = row["status"] == "active"
            if marked:
                connection.execute("UPDATE reservations SET status = 'expired_pending_release' WHERE id = ?", (reservation_id,))
        if marked:
            with self._lock:
                self._counters["marked_total"] += 1
                self._counters["mark_batches"] += 1
        if marked or row["status"] == "expired_pending_release":
            self._release_pending(now)
        raise CatalogError(409, "A reserva não está ativa ou seu prazo terminou.")

    def cancel(self, reservation_id):
        with self.database.connection(write=True) as connection:
            now = float(self.clock())
            row = self._row(connection, reservation_id)
            if row["status"] in ("cancelled", "expired"):
                return
            if row["status"] == "confirmed":
                raise CatalogError(409, "Uma reserva confirmada não pode ser cancelada.")
            if row["status"] == "active" and row["expires_at"] > now:
                connection.execute("UPDATE reservation_stock SET reserved = reserved - ? WHERE book_id = ?",
                                   (row["quantity"], row["book_id"]))
                connection.execute("UPDATE reservations SET status = 'cancelled', released_at = ? WHERE id = ?",
                                   (now, reservation_id))
                return
            marked = row["status"] == "active"
            if marked:
                connection.execute("UPDATE reservations SET status = 'expired_pending_release' WHERE id = ?", (reservation_id,))
        if marked:
            with self._lock:
                self._counters["marked_total"] += 1
                self._counters["mark_batches"] += 1
        self._release_pending(now)

    def _mark_due(self, now):
        ids = []
        with self._lock:
            if self._cache_healthy:
                try:
                    while self._schedule and self._schedule[0][0] <= now and len(ids) < self.batch_size:
                        ids.append(heapq.heappop(self._schedule)[1])
                except Exception:
                    self.invalidate_cache()
            sweep = (not self._cache_healthy or not self._schedule or now - self._last_sweep >= 1.0)
        # A bounded indexed sweep detects holds created by another service instance
        # and also recovers all due work if the cache has been lost.
        try:
            if sweep:
                with self.database.connection() as connection:
                    database_ids = [row[0] for row in connection.execute(
                        "SELECT id FROM reservations WHERE status = 'active' AND release_after <= ? "
                        "ORDER BY release_after LIMIT ?", (now, self.batch_size))]
                    # Durable candidates have priority over stale cache entries.
                    ids = database_ids + ids
                with self._lock:
                    self._last_sweep = now if len(ids) < self.batch_size else float("-inf")
            ids = list(dict.fromkeys(ids))[:self.batch_size]
            if not ids:
                return 0
            placeholders = ",".join("?" for _ in ids)
            with self.database.connection(write=True) as connection:
                marked = connection.execute(
                    f"UPDATE reservations SET status = 'expired_pending_release' WHERE id IN ({placeholders}) "
                    "AND status = 'active' AND expires_at <= ?", [*ids, now]).rowcount
            if marked:
                with self._lock:
                    self._counters["marked_total"] += marked
                    self._counters["mark_batches"] += 1
            return marked
        except Exception:
            self.invalidate_cache()
            raise

    def _release_pending(self, now):
        with self.database.connection() as connection:
            if not connection.execute("SELECT 1 FROM reservations WHERE status = 'expired_pending_release' LIMIT 1").fetchone():
                return 0
        with self.database.connection(write=True) as connection:
            rows = list(connection.execute("SELECT id, book_id, quantity, expires_at FROM reservations "
                "WHERE status = 'expired_pending_release' ORDER BY release_after LIMIT ?", (self.batch_size,)))
            if not rows:
                return 0
            quantities = Counter()
            for row in rows:
                quantities[row["book_id"]] += row["quantity"]
            for book_id, quantity in quantities.items():
                connection.execute("UPDATE reservation_stock SET reserved = reserved - ? WHERE book_id = ?",
                                   (quantity, book_id))
            placeholders = ",".join("?" for _ in rows)
            connection.execute(f"UPDATE reservations SET status = 'expired', released_at = ? WHERE id IN ({placeholders}) "
                               "AND status = 'expired_pending_release'", [now, *[row["id"] for row in rows]])
        with self._lock:
            self._counters["released_total"] += len(rows)
            self._counters["release_batches"] += 1
            self._counters["max_release_lag_seconds"] = max(
                self._counters["max_release_lag_seconds"], max(now - row["expires_at"] for row in rows))
        return len(rows)

    def process_due(self, now=None, *, collect_metrics=True):
        started = time.perf_counter()
        now = float(self.clock() if now is None else now)
        marked = self._mark_due(now)
        released = self._release_pending(now)
        with self._lock:
            self._counters["last_process_duration_seconds"] = time.perf_counter() - started
            counters = dict(self._counters)
        return {**(self.metrics(now=now) if collect_metrics else counters), "marked": marked, "released": released}

    def metrics(self, *, now=None):
        with self._lock:
            counters = dict(self._counters)
            cache = {"heap_entries": len(self._schedule), "cache_healthy": self._cache_healthy,
                     "worker_running": self._worker is not None and self._worker.is_alive()}
        with self.database.connection() as connection:
            now = float(self.clock() if now is None else now)
            counts = dict(connection.execute("SELECT status, count(*) FROM reservations GROUP BY status").fetchall())
            oldest = connection.execute("SELECT min(expires_at) FROM reservations "
                "WHERE status IN ('active','expired_pending_release') AND expires_at <= ?", (now,)).fetchone()[0]
            return {**counters, "active": counts.get("active", 0),
                    "pending_release": counts.get("expired_pending_release", 0),
                    "expired": counts.get("expired", 0), "confirmed": counts.get("confirmed", 0),
                    "cancelled": counts.get("cancelled", 0),
                    "oldest_overdue_seconds": max(0.0, now - oldest) if oldest is not None else 0.0,
                    **cache}
