"""POST /tasks : crée une tâche. Seule permission DynamoDB nécessaire : PutItem."""

import json
import logging
import uuid
from datetime import datetime, timezone
from typing import Any

from botocore.exceptions import ClientError
from pydantic import ValidationError

from app.handlers.common import error, get_table, parse_body, response, validation_details
from app.models import TaskCreate

logger = logging.getLogger()


def handler(event: dict[str, Any], context: Any) -> dict[str, Any]:
    try:
        task = TaskCreate.model_validate(parse_body(event))
    except ValidationError as exc:
        return error(400, "Données invalides", validation_details(exc))
    except json.JSONDecodeError:
        return error(400, "JSON invalide")
    except ValueError as exc:
        return error(400, str(exc))

    now = datetime.now(timezone.utc).isoformat()
    # id et dates sont générés côté serveur : le client ne peut pas les imposer.
    item = {"id": str(uuid.uuid4()), **task.model_dump(exclude_none=True), "created_at": now, "updated_at": now}

    try:
        # La condition garantit qu'on n'écrase jamais une tâche existante.
        get_table().put_item(Item=item, ConditionExpression="attribute_not_exists(id)")
    except ClientError:
        logger.exception("Échec du PutItem DynamoDB")
        return error(500, "Erreur interne")
    return response(201, item)
