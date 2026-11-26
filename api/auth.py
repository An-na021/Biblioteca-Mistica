"""Local identities, salted password hashes and revocable opaque sessions.

Bootstrap an administrator with: python -m api.auth create-admin USERNAME
No administrator, shared password or automatic role elevation is created at boot.
"""

import argparse
import getpass
import hashlib
import hmac
import os
import secrets
import time
import uuid

from .database import CatalogError, Database, PACKAGE


class AuthService:
    def __init__(self, database: Database, *, clock=time.time, session_seconds=43200):
        self.database = database
        self.clock = clock
        self.session_seconds = session_seconds

    def initialize(self):
        with self.database.connection(write=True) as connection:
            connection.executescript((PACKAGE / "auth_schema.sql").read_text(encoding="utf-8"))

    @staticmethod
    def _password(password, salt, algorithm):
        if algorithm == "scrypt":
            return hashlib.scrypt(password.encode(), salt=salt, n=16384, r=8, p=1, dklen=32)
        return hashlib.pbkdf2_hmac("sha256", password.encode(), salt, 600000, dklen=32)

    @staticmethod
    def _public(row):
        return {"id": row["id"], "username": row["username"], "role": row["role"]}

    def create_user(self, username, password, *, role="player"):
        if not isinstance(username, str) or not 3 <= len(username.strip()) <= 150:
            raise CatalogError(422, "O nome de usuário deve conter de 3 a 150 caracteres.")
        if not isinstance(password, str) or not 8 <= len(password) <= 1024:
            raise CatalogError(422, "A senha deve conter de 8 a 1024 caracteres.")
        if role not in ("player", "admin"):
            raise CatalogError(422, "Papel de usuário inválido.")
        username = username.strip().casefold()
        salt = secrets.token_bytes(16)
        algorithm = "scrypt"
        try:
            digest = self._password(password, salt, algorithm)
        except (AttributeError, ValueError):
            algorithm = "pbkdf2-sha256-600000"
            digest = self._password(password, salt, algorithm)
        user = {"id": uuid.uuid4().hex, "username": username, "role": role}
        with self.database.connection(write=True) as connection:
            if connection.execute("SELECT 1 FROM users WHERE username = ?", (username,)).fetchone():
                raise CatalogError(409, "Este nome de usuário já está cadastrado.")
            connection.execute("INSERT INTO users(id,username,password_salt,password_hash,password_algorithm,role) "
                               "VALUES (?, ?, ?, ?, ?, ?)",
                               (user["id"], username, salt.hex(), digest.hex(), algorithm, role))
            balance = connection.execute("SELECT starting_money FROM app_settings WHERE id = 1").fetchone()[0]
            connection.execute("INSERT INTO wallets(user_id,balance) VALUES (?, ?)", (user["id"], balance))
        return user

    def login(self, username, password):
        if not isinstance(username, str) or not isinstance(password, str) or len(password) > 1024:
            raise CatalogError(401, "Usuário ou senha inválidos.")
        with self.database.connection() as connection:
            row = connection.execute("SELECT * FROM users WHERE username = ?", (username.strip().casefold(),)).fetchone()
        if row is None:
            # Keep the same costly operation for unknown users.
            self._password(password, b"biblioteca-login", "pbkdf2-sha256-600000")
            raise CatalogError(401, "Usuário ou senha inválidos.")
        digest = self._password(password, bytes.fromhex(row["password_salt"]), row["password_algorithm"])
        if not hmac.compare_digest(digest.hex(), row["password_hash"]):
            raise CatalogError(401, "Usuário ou senha inválidos.")
        token = secrets.token_urlsafe(32)
        expires_at = float(self.clock()) + self.session_seconds
        with self.database.connection(write=True) as connection:
            connection.execute("DELETE FROM sessions WHERE expires_at <= ?", (float(self.clock()),))
            connection.execute("INSERT INTO sessions(token_hash,user_id,expires_at) VALUES (?, ?, ?)",
                               (hashlib.sha256(token.encode()).hexdigest(), row["id"], expires_at))
        return {"user": self._public(row), "token": token, "access_token": token,
                "token_type": "bearer", "expires_at": expires_at}

    def authenticate(self, token):
        if not isinstance(token, str) or not token or len(token) > 512:
            raise CatalogError(401, "Autenticação necessária.")
        with self.database.connection() as connection:
            row = connection.execute("SELECT users.* FROM sessions JOIN users ON users.id = sessions.user_id "
                                     "WHERE sessions.token_hash = ? AND sessions.expires_at > ?",
                                     (hashlib.sha256(token.encode()).hexdigest(), float(self.clock()))).fetchone()
        if row is None:
            raise CatalogError(401, "Sessão inválida ou expirada. Entre novamente.")
        return self._public(row)

    def logout(self, token):
        with self.database.connection(write=True) as connection:
            connection.execute("DELETE FROM sessions WHERE token_hash = ?", (hashlib.sha256(token.encode()).hexdigest(),))


def main():
    parser = argparse.ArgumentParser(description="Administração de contas locais da Biblioteca")
    parser.add_argument("action", choices=["create-admin"])
    parser.add_argument("username")
    parser.add_argument("--database", default=os.environ.get("BIBLIOTECA_DB_PATH", str(PACKAGE / "data" / "biblioteca.sqlite3")))
    args = parser.parse_args()
    password = getpass.getpass("Senha do administrador (mínimo 8 caracteres): ")
    if password != getpass.getpass("Repita a senha: "):
        parser.error("As senhas não conferem.")
    database = Database(args.database)
    database.initialize()
    service = AuthService(database)
    service.initialize()
    try:
        user = service.create_user(args.username, password, role="admin")
    except CatalogError as error:
        parser.error(error.message)
    print(f"Administrador criado: {user['username']}")


if __name__ == "__main__":
    main()
