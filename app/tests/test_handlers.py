"""Tests des 4 handlers contre un DynamoDB simulé."""

import json
import uuid

import pytest

from app.handlers import common, create_task, delete_task, get_tasks, update_task

UNKNOWN_ID = str(uuid.uuid4())


def body(resp: dict) -> dict:
    return json.loads(resp["body"])


def create(title: str = "Pain") -> dict:
    return create_task.handler({"body": json.dumps({"title": title})}, None)


# ---------- POST /tasks ----------

def test_create_returns_201_with_server_generated_fields(table) -> None:
    resp = create()
    assert resp["statusCode"] == 201
    data = body(resp)
    uuid.UUID(data["id"])  # l'identifiant est un UUID valide généré par le serveur
    assert {"created_at", "updated_at"} <= data.keys()
    assert table.get_item(Key={"id": data["id"]})["Item"]["title"] == "Pain"


@pytest.mark.parametrize(
    "event",
    [
        {},                                               # pas de corps
        {"body": "{"},                                    # JSON invalide
        {"body": "[1, 2]"},                               # pas un objet
        {"body": json.dumps({"title": "x", "id": "a"})},  # mass assignment
        {"body": "e30=", "isBase64Encoded": True},        # encodage non supporté
    ],
)
def test_create_rejects_bad_requests(table, event: dict) -> None:
    assert create_task.handler(event, None)["statusCode"] == 400
    assert table.scan()["Count"] == 0  # rien n'a été écrit


def test_validation_errors_do_not_echo_client_input(table) -> None:
    payload = "<script>alert(1)</script>" * 20
    resp = create_task.handler({"body": json.dumps({"title": payload})}, None)
    assert resp["statusCode"] == 400
    assert "<script>" not in resp["body"]


# ---------- GET /tasks ----------

def test_list_returns_created_tasks(table) -> None:
    create("A")
    create("B")
    resp = get_tasks.handler({}, None)
    assert resp["statusCode"] == 200
    assert sorted(t["title"] for t in body(resp)["tasks"]) == ["A", "B"]


# ---------- PUT /tasks/{id} ----------

def test_update_changes_only_sent_fields(table) -> None:
    task_id = body(create("Pain"))["id"]
    resp = update_task.handler({"pathParameters": {"id": task_id}, "body": json.dumps({"status": "done"})}, None)
    assert resp["statusCode"] == 200
    assert body(resp)["status"] == "done"
    assert body(resp)["title"] == "Pain"


def test_update_unknown_task_returns_404_and_creates_nothing(table) -> None:
    resp = update_task.handler({"pathParameters": {"id": UNKNOWN_ID}, "body": json.dumps({"status": "done"})}, None)
    assert resp["statusCode"] == 404
    assert table.scan()["Count"] == 0


@pytest.mark.parametrize("bad_id", ["abc", "../etc/passwd", "", None])
def test_update_rejects_invalid_id(table, bad_id) -> None:
    event = {"pathParameters": {"id": bad_id}, "body": json.dumps({"status": "done"})}
    assert update_task.handler(event, None)["statusCode"] == 400


def test_update_rejects_empty_body(table) -> None:
    task_id = body(create())["id"]
    assert update_task.handler({"pathParameters": {"id": task_id}, "body": "{}"}, None)["statusCode"] == 400


# ---------- DELETE /tasks/{id} ----------

def test_delete_then_404_on_second_delete(table) -> None:
    task_id = body(create())["id"]
    assert delete_task.handler({"pathParameters": {"id": task_id}}, None)["statusCode"] == 204
    assert delete_task.handler({"pathParameters": {"id": task_id}}, None)["statusCode"] == 404


def test_delete_rejects_invalid_id(table) -> None:
    assert delete_task.handler({"pathParameters": {"id": "abc"}}, None)["statusCode"] == 400


# ---------- Erreurs internes ----------

def test_internal_error_is_generic(table, monkeypatch: pytest.MonkeyPatch) -> None:
    """Si DynamoDB échoue (ici : table inexistante), le client ne voit aucun détail technique."""
    monkeypatch.setenv("TABLE_NAME", "table-qui-n-existe-pas")
    common.get_table.cache_clear()
    resp = get_tasks.handler({}, None)
    assert resp["statusCode"] == 500
    assert body(resp) == {"error": "Erreur interne"}
