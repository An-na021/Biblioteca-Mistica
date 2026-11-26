PRAGMA foreign_keys = ON;
CREATE TABLE IF NOT EXISTS metadata (key TEXT PRIMARY KEY, value TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS districts (id TEXT PRIMARY KEY, name TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS books (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL CHECK(length(trim(title)) > 0),
    author TEXT NOT NULL CHECK(length(trim(author)) > 0),
    sale_price INTEGER NOT NULL CHECK(sale_price > 0),
    buy_price INTEGER NOT NULL CHECK(buy_price > 0),
    description TEXT NOT NULL, tags TEXT NOT NULL,
    cover_color TEXT NOT NULL, cover_path TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS customers (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL CHECK(length(trim(name)) > 0),
    greeting TEXT NOT NULL, scene_path TEXT NOT NULL, personality TEXT NOT NULL,
    mood_type TEXT NOT NULL CHECK(mood_type IN ('apressado','indeciso','colecionador','negociador','dificil')),
    history TEXT NOT NULL, preferences TEXT NOT NULL, preference_tags TEXT NOT NULL,
    preferred_condition TEXT NOT NULL CHECK(preferred_condition IN ('novo','usado','danificado','raro'))
);
CREATE TABLE IF NOT EXISTS suppliers (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL CHECK(length(trim(name)) > 0),
    price_factor REAL NOT NULL CHECK(price_factor > 0 AND price_factor <= 10),
    risk REAL NOT NULL CHECK(risk >= 0 AND risk <= 1),
    description TEXT NOT NULL, tags TEXT NOT NULL,
    special_orders INTEGER NOT NULL CHECK(special_orders IN (0,1))
);
CREATE TABLE IF NOT EXISTS book_districts (
    book_id TEXT NOT NULL REFERENCES books(id) ON DELETE CASCADE,
    district_id TEXT NOT NULL REFERENCES districts(id),
    PRIMARY KEY(book_id, district_id)
);
CREATE TABLE IF NOT EXISTS customer_districts (
    customer_id TEXT NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
    district_id TEXT NOT NULL REFERENCES districts(id),
    PRIMARY KEY(customer_id, district_id)
);
CREATE INDEX IF NOT EXISTS book_district_lookup ON book_districts(district_id);
CREATE INDEX IF NOT EXISTS customer_district_lookup ON customer_districts(district_id);
-- Additive extension: this stock is independent from a player's saved inventory.
CREATE TABLE IF NOT EXISTS reservation_stock (
    book_id TEXT PRIMARY KEY REFERENCES books(id) ON DELETE CASCADE,
    total INTEGER NOT NULL DEFAULT 10 CHECK(total >= 0),
    reserved INTEGER NOT NULL DEFAULT 0 CHECK(reserved >= 0 AND reserved <= total)
);
CREATE TABLE IF NOT EXISTS reservations (
    id TEXT PRIMARY KEY,
    book_id TEXT NOT NULL REFERENCES books(id) ON DELETE CASCADE,
    quantity INTEGER NOT NULL CHECK(quantity > 0),
    status TEXT NOT NULL CHECK(status IN ('active','expired_pending_release','expired','confirmed','cancelled')),
    created_at REAL NOT NULL,
    expires_at REAL NOT NULL,
    release_after REAL NOT NULL,
    released_at REAL,
    CHECK(expires_at >= created_at AND release_after >= expires_at)
);
CREATE INDEX IF NOT EXISTS reservation_expiry_lookup ON reservations(status, release_after);
CREATE INDEX IF NOT EXISTS reservation_oldest_lookup ON reservations(status, expires_at);
CREATE INDEX IF NOT EXISTS reservation_book_lookup ON reservations(book_id, status);
PRAGMA user_version = 1;
