"""DELETE /tasks/{id} : supprime une tâche. Seule permission DynamoDB nécessaire : DeleteItem."""

import logging
from typing import Any

from botocore.exceptions import ClientError

from app.handlers.common import error, get_table, response, task_id_from_path

logger = logging.getLogger()


def handler(event: dict[str, Any], context: Any) -> dict[str, Any]:
    task_id = task_id_from_path(event)
    if task_id is None:
        return error(400, "Identifiant de tâche invalide")

    try:
        # La condition permet de répondre 404 si la tâche n'existe pas, au lieu d'un faux succès.
        get_table().delete_item(Key={"id": task_id}, ConditionExpression="attribute_exists(id)")
    except ClientError as exc:
        if exc.response["Error"]["Code"] == "ConditionalCheckFailedException":
            return error(404, "Tâche introuvable")
        logger.exception("Échec du DeleteItem DynamoDB")
        return error(500, "Erreur interne")
    return response(204)
