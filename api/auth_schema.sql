-- Additive local-account and commerce extension, independent of Godot saves.
CREATE TABLE IF NOT EXISTS users (
    id TEXT PRIMARY KEY,
    username TEXT NOT NULL COLLATE NOCASE UNIQUE,
    password_salt TEXT NOT NULL,
    password_hash TEXT NOT NULL,
    password_algorithm TEXT NOT NULL,
    role TEXT NOT NULL CHECK(role IN ('player','admin'))
);
CREATE TABLE IF NOT EXISTS sessions (
    token_hash TEXT PRIMARY KEY,
    user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    expires_at REAL NOT NULL
);
CREATE INDEX IF NOT EXISTS session_expiry_lookup ON sessions(expires_at);
CREATE TABLE IF NOT EXISTS wallets (
    user_id TEXT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    balance INTEGER NOT NULL CHECK(balance >= 0)
);
CREATE TABLE IF NOT EXISTS reservation_owners (
    reservation_id TEXT PRIMARY KEY REFERENCES reservations(id) ON DELETE CASCADE,
    user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS reservation_owner_lookup ON reservation_owners(user_id);
CREATE TABLE IF NOT EXISTS owned_books (
    user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    book_id TEXT NOT NULL,
    quantity INTEGER NOT NULL CHECK(quantity > 0),
    PRIMARY KEY(user_id, book_id)
);
CREATE TABLE IF NOT EXISTS payments (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    reservation_id TEXT NOT NULL UNIQUE,
    idempotency_key TEXT NOT NULL,
    book_id TEXT NOT NULL,
    quantity INTEGER NOT NULL CHECK(quantity > 0),
    amount INTEGER NOT NULL CHECK(amount > 0),
    balance_after INTEGER NOT NULL CHECK(balance_after >= 0),
    created_at REAL NOT NULL,
    UNIQUE(user_id, idempotency_key)
);
CREATE INDEX IF NOT EXISTS payment_user_lookup ON payments(user_id, created_at);
CREATE TABLE IF NOT EXISTS app_settings (
    id INTEGER PRIMARY KEY CHECK(id = 1),
    starting_money INTEGER NOT NULL CHECK(starting_money BETWEEN 0 AND 10000),
    shop_title TEXT NOT NULL,
    max_customers_per_day INTEGER NOT NULL CHECK(max_customers_per_day BETWEEN 1 AND 5)
);
INSERT OR IGNORE INTO app_settings(id, starting_money, shop_title, max_customers_per_day)
VALUES (1, 100, 'Biblioteca', 5);
