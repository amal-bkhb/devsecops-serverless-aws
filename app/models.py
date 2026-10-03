"""Modèles de données de l'API de tâches.

Toute donnée venant du client passe par ces modèles avant d'atteindre DynamoDB.
"""

from typing import Literal, Self

from pydantic import BaseModel, ConfigDict, Field, model_validator

TaskStatus = Literal["todo", "in_progress", "done"]

TITLE_MAX = 200
DESCRIPTION_MAX = 2000


class _StrictInput(BaseModel):
    """Base commune des entrées client.

    - extra="forbid" : tout champ inconnu est refusé (empêche le client
      d'imposer id, created_at ou tout autre champ interne : « mass assignment »).
    - str_strip_whitespace : supprime les espaces en début et fin de chaîne.
    """

    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)


class TaskCreate(_StrictInput):
    """Corps attendu pour POST /tasks."""

    title: str = Field(min_length=1, max_length=TITLE_MAX)
    description: str | None = Field(default=None, max_length=DESCRIPTION_MAX)
    status: TaskStatus = "todo"


class TaskUpdate(_StrictInput):
    """Corps attendu pour PUT /tasks/{id}. Tous les champs sont optionnels."""

    title: str | None = Field(default=None, min_length=1, max_length=TITLE_MAX)
    description: str | None = Field(default=None, max_length=DESCRIPTION_MAX)
    status: TaskStatus | None = None

    @model_validator(mode="after")
    def at_least_one_field(self) -> Self:
        """Refuse une mise à jour vide : elle n'a aucun sens et masquerait une erreur client."""
        if not self.model_fields_set:
            raise ValueError("Au moins un champ doit être fourni")
        return self
