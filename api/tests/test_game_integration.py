"""Integração real HTTP → SQLite → Godot; configure GODOT_BIN para executar."""

import json
import os
import shutil
import socket
import subprocess
import sys
import tempfile
import time
import unittest
import urllib.error
import urllib.request
from pathlib import Path

PROJECT = Path(__file__).resolve().parents[2]
GODOT = os.environ.get("GODOT_BIN") or shutil.which("godot")


@unittest.skipUnless(GODOT, "Configure GODOT_BIN com o executável do Godot 4.")
class GameIntegrationTests(unittest.TestCase):
    def test_crud_is_consumed_by_the_game(self):
        with tempfile.TemporaryDirectory() as temporary:
            with socket.socket() as listener:
                listener.bind(("127.0.0.1", 0))
                port = listener.getsockname()[1]
            environment = {**os.environ, "BIBLIOTECA_DB_PATH": str(Path(temporary) / "test.sqlite3"),
                           "BIBLIOTECA_API_URL": f"http://127.0.0.1:{port}"}
            server = subprocess.Popen(
                [sys.executable, "-m", "uvicorn", "api.main:app", "--host", "127.0.0.1", "--port", str(port)],
                cwd=PROJECT, env=environment, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                creationflags=subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0,
            )
            try:
                def request(method, endpoint, payload=None):
                    data = json.dumps(payload).encode() if payload is not None else None
                    request = urllib.request.Request(environment["BIBLIOTECA_API_URL"] + endpoint,
                                                     data=data, method=method, headers={"Content-Type": "application/json"})
                    with urllib.request.urlopen(request, timeout=3) as response:
                        body = response.read()
                        return json.loads(body) if body else None

                deadline = time.monotonic() + 12
                while True:
                    try:
                        request("GET", "/api/health")
                        break
                    except (OSError, urllib.error.URLError):
                        if server.poll() is not None or time.monotonic() >= deadline:
                            self.fail("API não iniciou: " + server.communicate(timeout=2)[0].decode(errors="replace"))
                        time.sleep(0.1)
                seed = request("GET", "/api/catalog")
                request("POST", "/api/books", {**seed["books"][0], "id": "api_livro", "title": "Cadastro pela API", "tags": ["magia"], "district_ids": ["centro"]})
                request("POST", "/api/customers", {**seed["customers"][0], "id": "api_leitor", "name": "Leitor da API", "preference_tags": ["magia"], "preferred_condition": "novo", "district_ids": ["centro"]})
                request("POST", "/api/suppliers", {**seed["suppliers"][0], "id": "api_fornecedor", "name": "Fornecedor da API", "special_orders": True, "tags": [], "risk": 0})
                request("DELETE", "/api/suppliers/praca")
                request("PATCH", "/api/books/jardim_horas", {"sale_price": 19})
                result = subprocess.run([str(GODOT), "--headless", "--path", str(PROJECT), "--script", "tests/test_catalog_api.gd",
                                         "--log-file", str(Path(temporary) / "godot.log")],
                                        cwd=PROJECT, env=environment, capture_output=True, timeout=25)
                output = (result.stdout + result.stderr).decode(errors="replace")
                self.assertEqual(result.returncode, 0, output)
                self.assertIn("RESULT: 0 failure(s)", output)
                self.assertNotIn("SCRIPT ERROR", output)
            finally:
                server.terminate()
                server.communicate(timeout=8)
