"""Contratos de entrada iguais aos campos consumidos pelo jogo."""

from typing import Annotated, Literal
from pydantic import BaseModel, ConfigDict, Field, field_validator

Identifier = Annotated[str, Field(pattern=r"^[a-z][a-z0-9_]{0,63}$")]
Text = Annotated[str, Field(min_length=1, max_length=150)]
Money = Annotated[int, Field(strict=True, gt=0, le=1_000_000)]
Tag = Annotated[str, Field(pattern=r"^[a-z][a-z0-9_]{0,39}$")]
District = Literal["centro", "bosque", "minas"]
Districts = Annotated[list[District], Field(min_length=1, max_length=3)]
Tags = Annotated[list[Tag], Field(min_length=1, max_length=20)]
Scene = Literal[
    "res://scenes/characters/elfa.tscn", "res://scenes/characters/aprendiz.tscn",
    "res://scenes/characters/mago.tscn", "res://scenes/characters/anao.tscn",
    "res://scenes/characters/thalion_grimorio.tscn",
    "res://scenes/characters/professor_bigodes.tscn",
    "res://scenes/characters/lilith_vespera.tscn", "res://scenes/characters/evelune.tscn",
]

class Record(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True, allow_inf_nan=False)
    id: Identifier

    @field_validator("*", mode="after")
    @classmethod
    def unique_list_values(cls, value):
        if isinstance(value, list) and len(value) != len(set(value)):
            raise ValueError("A lista não pode conter valores repetidos.")
        return value

class Book(Record):
    title: Text
    author: Text
    sale_price: Money
    buy_price: Money
    description: Annotated[str, Field(max_length=2000)] = ""
    tags: Tags
    district_ids: Districts
    cover_color: Annotated[str, Field(pattern=r"^#[0-9a-fA-F]{6}$")] = "#604b78"
    cover_path: Annotated[str, Field(max_length=200)] = ""

class Customer(Record):
    name: Text
    greeting: Annotated[str, Field(max_length=300)] = "Olá"
    scene_path: Scene = "res://scenes/characters/aprendiz.tscn"
    personality: Annotated[str, Field(max_length=2000)] = ""
    mood_type: Literal["apressado", "indeciso", "colecionador", "negociador", "dificil"] = "indeciso"
    history: Annotated[str, Field(max_length=2000)] = ""
    preferences: Annotated[str, Field(max_length=2000)] = ""
    preference_tags: Tags
    preferred_condition: Literal["novo", "usado", "danificado", "raro"] = "novo"
    district_ids: Districts

class Supplier(Record):
    name: Text
    price_factor: Annotated[float, Field(gt=0, le=10)] = 1.0
    risk: Annotated[float, Field(ge=0, le=1)] = 0.0
    description: Annotated[str, Field(max_length=2000)] = ""
    tags: Annotated[list[Tag], Field(max_length=20)] = Field(default_factory=list)
    special_orders: bool = False

MODELS = {"books": Book, "customers": Customer, "suppliers": Supplier}
