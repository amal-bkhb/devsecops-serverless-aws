"""GET /tasks : liste les tâches. Seule permission DynamoDB nécessaire : Scan."""

import logging
from typing import Any

from botocore.exceptions import ClientError

from app.handlers.common import error, get_table, response

logger = logging.getLogger()

# Plafond du nombre d'éléments lus par appel : limite le coût et la taille de la réponse.
MAX_ITEMS = 100


def handler(event: dict[str, Any], context: Any) -> dict[str, Any]:
    try:
        result = get_table().scan(Limit=MAX_ITEMS)
    except ClientError:
        logger.exception("Échec du Scan DynamoDB")
        return error(500, "Erreur interne")
    return response(200, {"tasks": result.get("Items", [])})
