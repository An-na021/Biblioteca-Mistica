"""Interface local para os serviços de conta, estoque e compra em moedas."""

from pathlib import Path

from fastapi import APIRouter, HTTPException
from fastapi.responses import FileResponse

from .database import PACKAGE, PROJECT


def portal_router():
    router = APIRouter()

    @router.get("/portal", include_in_schema=False)
    def portal():
        return FileResponse(PACKAGE / "portal.html", media_type="text/html; charset=utf-8")

    @router.get("/book-covers/{filename}", include_in_schema=False)
    def cover(filename: str):
        directory = (PROJECT / "bookimg").resolve()
        path = (directory / filename).resolve()
        if path.parent != directory or path.suffix.lower() not in {".png", ".jpg", ".jpeg", ".webp"} or not path.is_file():
            raise HTTPException(404, "Capa não encontrada.")
        return FileResponse(path)

    return router
