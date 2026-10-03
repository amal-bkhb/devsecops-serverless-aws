"""Tests des règles de validation des entrées."""

import pytest
from pydantic import ValidationError

from app.models import TaskCreate, TaskUpdate


def test_create_valid_strips_whitespace_and_defaults_status() -> None:
    task = TaskCreate(title="  Acheter du pain  ")
    assert task.title == "Acheter du pain"
    assert task.status == "todo"


@pytest.mark.parametrize(
    "payload",
    [
        {"title": ""},                      # titre vide
        {"title": "   "},                   # titre composé uniquement d'espaces
        {"title": "a" * 201},               # titre trop long
        {"title": "x", "description": "d" * 2001},
        {"title": "x", "status": "urgent"},  # statut inconnu
        {"title": "x", "id": "pirate"},      # mass assignment
        {},                                 # titre manquant
    ],
)
def test_create_rejects_invalid_input(payload: dict) -> None:
    with pytest.raises(ValidationError):
        TaskCreate(**payload)


def test_update_rejects_empty_body() -> None:
    with pytest.raises(ValidationError):
        TaskUpdate()


def test_update_keeps_only_sent_fields() -> None:
    assert TaskUpdate(status="done").model_dump(exclude_unset=True) == {"status": "done"}
