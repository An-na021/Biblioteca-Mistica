"""Execute: python -m uvicorn api.main:app --host 127.0.0.1 --port 8000."""

import os
import sqlite3
from contextlib import asynccontextmanager
from pathlib import Path
from typing import Annotated

from fastapi import APIRouter, FastAPI, Query, Request, Response
from fastapi.encoders import jsonable_encoder
from fastapi.responses import JSONResponse, RedirectResponse
from pydantic import ConfigDict, ValidationError, create_model

from .database import CatalogError, Database, PACKAGE
from .models import District, MODELS


def create_app(database_path: str | Path | None = None) -> FastAPI:
    database = Database(database_path or os.environ.get("BIBLIOTECA_DB_PATH", str(PACKAGE / "data" / "biblioteca.sqlite3")))

    @asynccontextmanager
    async def lifespan(application):
        database.initialize()
        yield

    application = FastAPI(
        title="Biblioteca · API de catálogo", version="1.0.0", lifespan=lifespan,
        description="CRUD de livros, clientes e fornecedores. SQLite persistente. Os preços são inteiros em moedas; os identificadores são imutáveis. Alterações incompatíveis com os bairros retornam 409 e são desfeitas.",
    )
    application.state.database = database

    @application.exception_handler(CatalogError)
    async def catalog_error(request: Request, exception: CatalogError):
        return JSONResponse(status_code=exception.status, content={"detail": exception.message})

    @application.exception_handler(ValidationError)
    async def invalid_update(request: Request, exception: ValidationError):
        return JSONResponse(status_code=422, content={"detail": jsonable_encoder(exception.errors(), custom_encoder={ValueError: str})})

    @application.exception_handler(sqlite3.Error)
    async def database_error(request: Request, exception: sqlite3.Error):
        # No SQL statements, paths or internal exception details in HTTP responses.
        return JSONResponse(status_code=503, content={"detail": "Banco indisponível no momento. Tente novamente."})

    @application.get("/", include_in_schema=False)
    def index():
        return RedirectResponse("/docs")

    @application.get("/api/health", tags=["Sistema"])
    def health():
        with database.connection() as connection:
            connection.execute("SELECT 1").fetchone()
        return {"status": "ok", "database": "sqlite", "schema_version": 1}

    @application.get("/api/catalog", tags=["Integração com o jogo"])
    def catalog():
        return database.catalog()

    for resource, schema in MODELS.items():
        application.include_router(resource_router(database, resource, schema))
    return application


def resource_router(database: Database, resource: str, schema):
    router = APIRouter(prefix=f"/api/{resource}", tags=[resource], responses={
        404: {"description": "Registro não encontrado"},
        409: {"description": "Identificador repetido ou alteração incompatível com o jogo"},
        503: {"description": "Banco temporariamente indisponível"},
    })
    page = create_model(f"{schema.__name__}Page", items=(list[schema], ...), total=(int, ...), limit=(int, ...), offset=(int, ...))
    # exclude_unset distinguishes omitted fields from explicit null values.
    patch_schema = create_model(f"{schema.__name__}Patch", __config__=ConfigDict(extra="forbid"), **{
        name: (field.rebuild_annotation() | None, None) for name, field in schema.model_fields.items() if name != "id"
    })

    @router.get("", response_model=page, summary="Listar e pesquisar")
    def list_records(q: Annotated[str, Query(max_length=150)] = "", district: District | None = None,
                     tag: Annotated[str | None, Query(max_length=40)] = None,
                     limit: Annotated[int, Query(ge=1, le=200)] = 50,
                     offset: Annotated[int, Query(ge=0)] = 0):
        return database.list(resource, q=q, district=district, tag=tag, limit=limit, offset=offset)

    @router.get("/{record_id}", response_model=schema, summary="Consultar por identificador")
    def get_record(record_id: str):
        return database.get(resource, record_id)

    @router.post("", response_model=schema, status_code=201, summary="Cadastrar")
    def create_record(payload: schema, response: Response):
        result = database.create(resource, payload.model_dump())
        response.headers["Location"] = f"/api/{resource}/{result['id']}"
        return result

    @router.put("/{record_id}", response_model=schema, summary="Substituir todos os campos")
    def replace_record(record_id: str, payload: schema):
        return database.update(resource, record_id, payload.model_dump())

    @router.patch("/{record_id}", response_model=schema, summary="Atualizar campos selecionados")
    def patch_record(record_id: str, payload: patch_schema):
        changes = payload.model_dump(exclude_unset=True)
        if not changes:
            raise CatalogError(422, "Informe ao menos um campo para atualizar.")
        return database.update(resource, record_id, changes, partial=True)

    @router.delete("/{record_id}", status_code=204, summary="Excluir")
    def delete_record(record_id: str):
        database.delete(resource, record_id)
        return Response(status_code=204)

    return router


app = create_app()
