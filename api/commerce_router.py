"""HTTP boundaries for local accounts, stock holds and coin payments."""

from typing import Annotated

from fastapi import APIRouter, Depends, Response
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from pydantic import BaseModel, ConfigDict, Field

from .database import CatalogError


class Credentials(BaseModel):
    model_config = ConfigDict(extra="forbid")
    username: Annotated[str, Field(min_length=3, max_length=150)]
    password: Annotated[str, Field(min_length=8, max_length=1024)]


class StockUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")
    total: Annotated[int, Field(strict=True, ge=0, le=2147483647)]


class ReservationRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")
    book_id: Annotated[str, Field(min_length=1, max_length=64)]
    quantity: Annotated[int, Field(strict=True, ge=1, le=2147483647)] = 1


class CheckoutRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")
    reservation_id: Annotated[str, Field(min_length=1, max_length=64)]
    idempotency_key: Annotated[str, Field(min_length=1, max_length=150)]


class SettingsPatch(BaseModel):
    model_config = ConfigDict(extra="forbid")
    starting_money: Annotated[int, Field(strict=True, ge=0, le=10000)] | None = None
    shop_title: Annotated[str, Field(min_length=1, max_length=100)] | None = None
    max_customers_per_day: Annotated[int, Field(strict=True, ge=1, le=5)] | None = None


def auth_dependencies(auth):
    bearer = HTTPBearer(auto_error=False)

    def current_user(credentials: HTTPAuthorizationCredentials | None = Depends(bearer)):
        if credentials is None:
            raise CatalogError(401, "Autenticação necessária.")
        return auth.authenticate(credentials.credentials)

    def administrator(user=Depends(current_user)):
        if user["role"] != "admin":
            raise CatalogError(403, "Esta operação exige uma conta administradora.")
        return user

    return current_user, administrator


def commerce_router(auth, commerce, reservations, current_user, administrator):
    router = APIRouter()

    @router.post("/api/auth/register", status_code=201, tags=["Contas locais"])
    def register(payload: Credentials):
        auth.create_user(payload.username, payload.password)
        return auth.login(payload.username, payload.password)

    @router.post("/api/auth/login", tags=["Contas locais"])
    def login(payload: Credentials):
        return auth.login(payload.username, payload.password)

    @router.post("/api/auth/logout", status_code=204, tags=["Contas locais"])
    def logout(user=Depends(current_user), credentials=Depends(HTTPBearer())):
        auth.logout(credentials.credentials)
        return Response(status_code=204)

    @router.get("/api/me", tags=["Contas locais"])
    def me(user=Depends(current_user)):
        return {"user": user, "wallet": commerce.wallet(user["id"])}

    @router.get("/api/stock", tags=["Reservas temporárias"])
    def stock():
        return reservations.book_stock()

    @router.put("/api/stock/{book_id}", tags=["Reservas temporárias"])
    def set_stock(book_id: str, payload: StockUpdate, user=Depends(administrator)):
        return reservations.set_stock(book_id, payload.total)

    @router.post("/api/reservations", status_code=201, tags=["Reservas temporárias"])
    @router.post("/api/store/reservations", status_code=201, include_in_schema=False)
    def reserve(payload: ReservationRequest, response: Response, user=Depends(current_user)):
        result = reservations.reserve(payload.book_id, payload.quantity, owner_id=user["id"])
        response.headers["Location"] = f"/api/reservations/{result['id']}"
        return result

    @router.get("/api/reservations/metrics", tags=["Reservas temporárias"])
    def metrics(user=Depends(administrator)):
        return reservations.metrics()

    @router.get("/api/reservations/{reservation_id}", tags=["Reservas temporárias"])
    def reservation(reservation_id: str, user=Depends(current_user)):
        commerce.check_owner(reservation_id, user)
        return reservations.get(reservation_id)

    @router.post("/api/reservations/{reservation_id}/confirm", tags=["Reservas temporárias"],
                 summary="Confirmação administrativa, sem pagamento; use checkout para comprar")
    def confirm(reservation_id: str, user=Depends(administrator)):
        return reservations.confirm(reservation_id)

    @router.delete("/api/reservations/{reservation_id}", status_code=204, tags=["Reservas temporárias"])
    def cancel(reservation_id: str, user=Depends(current_user)):
        commerce.check_owner(reservation_id, user)
        reservations.cancel(reservation_id)
        return Response(status_code=204)

    @router.post("/api/checkout", tags=["Compras em moedas"])
    def checkout(payload: CheckoutRequest, user=Depends(current_user)):
        return commerce.checkout(user["id"], payload.reservation_id, payload.idempotency_key)

    @router.get("/api/library", tags=["Compras em moedas"])
    def library(user=Depends(current_user)):
        return commerce.library(user["id"])

    @router.get("/api/payments", tags=["Compras em moedas"])
    def payments(user=Depends(current_user)):
        return commerce.payments(user["id"])

    @router.get("/api/settings", tags=["Configuração"])
    def settings():
        return commerce.settings()

    @router.patch("/api/settings", tags=["Configuração"])
    def update_settings(payload: SettingsPatch, user=Depends(administrator)):
        return commerce.update_settings(payload.model_dump(exclude_unset=True))

    return router
