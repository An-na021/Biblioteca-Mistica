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
PRAGMA user_version = 1;
