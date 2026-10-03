"""PUT /tasks/{id} : modifie une tâche. Seule permission DynamoDB nécessaire : UpdateItem."""

import json
import logging
from datetime import datetime, timezone
from typing import Any

from botocore.exceptions import ClientError
from pydantic import ValidationError

from app.handlers.common import error, get_table, parse_body, response, task_id_from_path, validation_details
from app.models import TaskUpdate

logger = logging.getLogger()


def handler(event: dict[str, Any], context: Any) -> dict[str, Any]:
    task_id = task_id_from_path(event)
    if task_id is None:
        return error(400, "Identifiant de tâche invalide")

    try:
        changes = TaskUpdate.model_validate(parse_body(event)).model_dump(exclude_unset=True)
    except ValidationError as exc:
        return error(400, "Données invalides", validation_details(exc))
    except json.JSONDecodeError:
        return error(400, "JSON invalide")
    except ValueError as exc:
        return error(400, str(exc))

    changes["updated_at"] = datetime.now(timezone.utc).isoformat()
    # Noms et valeurs passés en paramètres (#n0, :v0) : jamais de concaténation de données client
    # dans l'expression. "status" est en plus un mot réservé DynamoDB.
    names = {f"#n{i}": key for i, key in enumerate(changes)}
    values = {f":v{i}": value for i, value in enumerate(changes.values())}
    expression = "SET " + ", ".join(f"#n{i} = :v{i}" for i in range(len(changes)))

    try:
        result = get_table().update_item(
            Key={"id": task_id},
            UpdateExpression=expression,
            ExpressionAttributeNames=names,
            ExpressionAttributeValues=values,
            # Sans cette condition, UpdateItem créerait silencieusement une tâche inexistante.
            ConditionExpression="attribute_exists(id)",
            ReturnValues="ALL_NEW",
        )
    except ClientError as exc:
        if exc.response["Error"]["Code"] == "ConditionalCheckFailedException":
            return error(404, "Tâche introuvable")
        logger.exception("Échec du UpdateItem DynamoDB")
        return error(500, "Erreur interne")
    return response(200, result["Attributes"])
