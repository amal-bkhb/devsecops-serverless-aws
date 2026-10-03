"""Fonctions partagées par les 4 handlers Lambda."""

import json
import logging
import os
import uuid
from functools import lru_cache
from typing import Any

import boto3
from pydantic import ValidationError

logger = logging.getLogger()
logger.setLevel(os.environ.get("LOG_LEVEL", "INFO"))

JSON_HEADERS = {"Content-Type": "application/json"}


@lru_cache(maxsize=1)
def get_table() -> Any:
    """Retourne la table DynamoDB.

    Le nom vient de la variable d'environnement TABLE_NAME (fixée par Terraform) :
    aucun nom ni région en dur dans le code. La région est fournie par Lambda (AWS_REGION).
    Le cache évite de recréer le client à chaque invocation (réutilisation entre appels).
    """
    return boto3.resource("dynamodb").Table(os.environ["TABLE_NAME"])


def response(status: int, body: Any = None) -> dict[str, Any]:
    """Construit une réponse au format attendu par API Gateway (HTTP API, payload v2)."""
    result: dict[str, Any] = {"statusCode": status, "headers": JSON_HEADERS}
    if body is not None:
        result["body"] = json.dumps(body, ensure_ascii=False)
    return result


def error(status: int, message: str, details: list[dict[str, str]] | None = None) -> dict[str, Any]:
    """Réponse d'erreur générique, sans trace technique ni donnée interne."""
    body: dict[str, Any] = {"error": message}
    if details:
        body["details"] = details
    return response(status, body)


def parse_body(event: dict[str, Any]) -> dict[str, Any]:
    """Lit le corps JSON de la requête. Lève ValueError si absent ou invalide."""
    raw = event.get("body")
    if not raw:
        raise ValueError("Corps de requête manquant")
    if event.get("isBase64Encoded"):
        raise ValueError("Encodage du corps non supporté")
    data = json.loads(raw)
    if not isinstance(data, dict):
        raise ValueError("Le corps doit être un objet JSON")
    return data


def validation_details(exc: ValidationError) -> list[dict[str, str]]:
    """Résume les erreurs Pydantic SANS renvoyer la valeur envoyée par le client.

    Renvoyer l'entrée telle quelle (champ "input" de Pydantic) pourrait refléter
    du contenu malveillant ou volumineux dans la réponse.
    """
    return [
        {"field": ".".join(str(p) for p in err["loc"]) or "body", "message": err["msg"]}
        for err in exc.errors(include_input=False, include_url=False)
    ]


def task_id_from_path(event: dict[str, Any]) -> str | None:
    """Extrait et valide l'identifiant de tâche du chemin. Retourne None s'il est invalide."""
    raw = (event.get("pathParameters") or {}).get("id", "")
    try:
        return str(uuid.UUID(raw))
    except (ValueError, TypeError):
        return None
