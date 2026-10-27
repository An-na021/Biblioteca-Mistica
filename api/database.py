"""Persistência SQLite com transações e consultas parametrizadas."""

import json
import sqlite3
import unicodedata
from contextlib import closing, contextmanager
from pathlib import Path

from .models import MODELS

PACKAGE = Path(__file__).resolve().parent
PROJECT = PACKAGE.parent
DISTRICTS = {"centro": "Centro Antigo", "bosque": "Bairro das Folhas", "minas": "Distrito das Minas"}
RELATIONS = {"books": ("book_districts", "book_id"), "customers": ("customer_districts", "customer_id")}
JSON_FIELDS = {"tags", "preference_tags"}


class CatalogError(Exception):
    def __init__(self, status: int, message: str):
        self.status = status
        self.message = message


def normalize(value: str) -> str:
    return "".join(c for c in unicodedata.normalize("NFD", value.casefold()) if not unicodedata.combining(c))


class Database:
    def __init__(self, path: str | Path):
        self.path = Path(path)

    @contextmanager
    def connection(self, write=False):
        connection = sqlite3.connect(self.path, timeout=5)
        connection.row_factory = sqlite3.Row
        connection.execute("PRAGMA foreign_keys = ON")
        connection.create_function("normalize", 1, normalize, deterministic=True)
        try:
            connection.execute("BEGIN IMMEDIATE" if write else "BEGIN")
            yield connection
            connection.commit()
        except Exception:
            connection.rollback()
            raise
        finally:
            connection.close()

    def initialize(self):
        self.path.parent.mkdir(parents=True, exist_ok=True)
        with closing(sqlite3.connect(self.path)) as connection:
            connection.execute("PRAGMA journal_mode = WAL")
            version = connection.execute("PRAGMA user_version").fetchone()[0]
            if version > 1:
                raise RuntimeError("Versão do banco mais recente que esta API.")
            connection.executescript((PACKAGE / "schema.sql").read_text(encoding="utf-8"))
        with self.connection(write=True) as connection:
            if connection.execute("SELECT value FROM metadata WHERE key = ?", ("seed_version",)).fetchone():
                return
            connection.executemany("INSERT OR IGNORE INTO districts(id, name) VALUES (?, ?)", DISTRICTS.items())
            seed = json.loads((PACKAGE / "seed.json").read_text(encoding="utf-8"))
            for resource, schema in MODELS.items():
                for original in seed[resource]:
                    self._persist(connection, resource, schema.model_validate(original).model_dump())
            self._validate_playable(connection)
            connection.execute("INSERT INTO metadata(key, value) VALUES (?, ?)", ("seed_version", "1"))

    def _decode(self, connection, resource, row):
        if row is None:
            raise CatalogError(404, "Registro não encontrado.")
        item = dict(row)
        for field in JSON_FIELDS.intersection(item):
            item[field] = json.loads(item[field])
        if "special_orders" in item:
            item["special_orders"] = bool(item["special_orders"])
        if resource in RELATIONS:
            relation, foreign = RELATIONS[resource]
            item["district_ids"] = [row[0] for row in connection.execute(
                f"SELECT district_id FROM {relation} WHERE {foreign} = ? ORDER BY district_id", (item["id"],)
            )]
        return item

    def _all(self, connection, resource):
        return [self._decode(connection, resource, row) for row in connection.execute(f"SELECT * FROM {resource} ORDER BY id")]

    def _get(self, connection, resource, record_id):
        return self._decode(connection, resource, connection.execute(f"SELECT * FROM {resource} WHERE id = ?", (record_id,)).fetchone())

    def get(self, resource, record_id):
        with self.connection() as connection:
            return self._get(connection, resource, record_id)

    def catalog(self):
        with self.connection() as connection:
            return {resource: self._all(connection, resource) for resource in MODELS}

    def list(self, resource, *, q="", district=None, tag=None, limit=50, offset=0):
        filters, bindings = [], []
        if q:
            column = "title || ' ' || author" if resource == "books" else "name"
            filters.append(f"instr(normalize({column}), ?) > 0")
            bindings.append(normalize(q))
        if district:
            if resource not in RELATIONS:
                raise CatalogError(422, "Fornecedores não possuem bairro; use o filtro de tema.")
            relation, foreign = RELATIONS[resource]
            filters.append(f"EXISTS (SELECT 1 FROM {relation} WHERE {foreign} = {resource}.id AND district_id = ?)")
            bindings.append(district)
        if tag:
            field = "preference_tags" if resource == "customers" else "tags"
            filters.append(f"EXISTS (SELECT 1 FROM json_each({resource}.{field}) WHERE value = ?)")
            bindings.append(tag)
        where = " WHERE " + " AND ".join(filters) if filters else ""
        with self.connection() as connection:
            total = connection.execute(f"SELECT count(*) FROM {resource}{where}", bindings).fetchone()[0]
            rows = connection.execute(f"SELECT * FROM {resource}{where} ORDER BY id LIMIT ? OFFSET ?", [*bindings, limit, offset])
            return {"items": [self._decode(connection, resource, row) for row in rows], "total": total, "limit": limit, "offset": offset}

    def _persist(self, connection, resource, data, update=False):
        values = {key: json.dumps(value, ensure_ascii=False) if key in JSON_FIELDS else value
                  for key, value in data.items() if key != "district_ids"}
        if resource == "books" and data["cover_path"]:
            cover = data["cover_path"]
            relative = Path(cover.removeprefix("res://"))
            if (not cover.startswith("res://bookimg/") or ".." in relative.parts or "\\" in cover
                    or relative.suffix.lower() not in {".png", ".jpg", ".jpeg", ".webp"}
                    or not (PROJECT / relative).is_file()):
                raise CatalogError(422, "Capa inválida. Use um arquivo existente em res://bookimg/ ou deixe vazio.")
        if update:
            fields = [field for field in values if field != "id"]
            assignments = ", ".join(f"{field} = ?" for field in fields)
            connection.execute(f"UPDATE {resource} SET {assignments} WHERE id = ?", [*[values[field] for field in fields], values["id"]])
        else:
            fields = list(values)
            connection.execute(f"INSERT INTO {resource} ({', '.join(fields)}) VALUES ({', '.join('?' for _ in fields)})", list(values.values()))
        if resource in RELATIONS:
            relation, foreign = RELATIONS[resource]
            connection.execute(f"DELETE FROM {relation} WHERE {foreign} = ?", (data["id"],))
            connection.executemany(f"INSERT INTO {relation}({foreign}, district_id) VALUES (?, ?)", [(data["id"], district) for district in data["district_ids"]])

    def create(self, resource, data):
        with self.connection(write=True) as connection:
            if connection.execute(f"SELECT 1 FROM {resource} WHERE id = ?", (data["id"],)).fetchone():
                raise CatalogError(409, "Já existe um registro com este identificador.")
            self._persist(connection, resource, data)
            self._validate_playable(connection)
            return self._get(connection, resource, data["id"])

    def update(self, resource, record_id, data, *, partial=False):
        with self.connection(write=True) as connection:
            previous = self._get(connection, resource, record_id)
            if not partial and data["id"] != record_id:
                raise CatalogError(409, "O identificador do registro não pode ser alterado.")
            data = MODELS[resource].model_validate({**previous, **data} if partial else data).model_dump()
            self._persist(connection, resource, data, update=True)
            self._validate_playable(connection)
            return self._get(connection, resource, record_id)

    def delete(self, resource, record_id):
        with self.connection(write=True) as connection:
            self._get(connection, resource, record_id)
            connection.execute(f"DELETE FROM {resource} WHERE id = ?", (record_id,))
            self._validate_playable(connection)

    def _validate_playable(self, connection):
        """Impede que uma alteração deixe o jogo sem atendimento possível."""
        catalog = {resource: self._all(connection, resource) for resource in MODELS}
        if not any(supplier["special_orders"] for supplier in catalog["suppliers"]):
            raise CatalogError(409, "Mantenha ao menos um fornecedor que aceite encomendas especiais.")
        for district in DISTRICTS:
            customers = [item for item in catalog["customers"] if district in item["district_ids"]]
            if not customers:
                raise CatalogError(409, f"O bairro {DISTRICTS[district]} precisa de ao menos um cliente.")
            books = [item for item in catalog["books"] if district in item["district_ids"]]
            for customer in customers:
                if not any(set(book["tags"]) & set(customer["preference_tags"]) for book in books):
                    raise CatalogError(409, f"O cliente {customer['name']} precisa de um livro compatível no bairro {DISTRICTS[district]}.")
