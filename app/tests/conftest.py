"""Configuration commune des tests : DynamoDB simulé par moto, jamais de vrai appel AWS."""

import os

import boto3
import pytest
from moto import mock_aws

from app.handlers import common


@pytest.fixture(autouse=True)
def aws_env(monkeypatch: pytest.MonkeyPatch) -> None:
    """Faux identifiants et région : si un test sortait du mock, il échouerait au lieu de toucher ton compte."""
    monkeypatch.setenv("AWS_ACCESS_KEY_ID", "testing")
    monkeypatch.setenv("AWS_SECRET_ACCESS_KEY", "testing")
    monkeypatch.setenv("AWS_SESSION_TOKEN", "testing")
    monkeypatch.setenv("AWS_DEFAULT_REGION", "eu-west-3")
    monkeypatch.delenv("AWS_PROFILE", raising=False)
    monkeypatch.setenv("TABLE_NAME", "tasks-test")
    common.get_table.cache_clear()


@pytest.fixture
def table():
    """Table DynamoDB vide, recréée pour chaque test."""
    with mock_aws():
        dynamodb = boto3.resource("dynamodb")
        tbl = dynamodb.create_table(
            TableName=os.environ["TABLE_NAME"],
            KeySchema=[{"AttributeName": "id", "KeyType": "HASH"}],
            AttributeDefinitions=[{"AttributeName": "id", "AttributeType": "S"}],
            BillingMode="PAY_PER_REQUEST",
        )
        yield tbl
        common.get_table.cache_clear()
