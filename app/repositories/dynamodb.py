"""DynamoDB repository — the production backend.

Uses a full-table Scan: the dataset is a small, bounded catalog and the
recommendation query filters on multiple optional attributes, which fits
scan-and-filter better than designing GSIs per filter combination. At real
scale this would become a GSI on `style` plus in-app residual filtering —
documented trade-off.
"""

import logging
from typing import Any

import boto3
from botocore.exceptions import BotoCoreError, ClientError

from app.models.restaurant import Restaurant

logger = logging.getLogger(__name__)


class DynamoDBRestaurantRepository:
    def __init__(self, table_name: str, region: str) -> None:
        # No explicit credentials anywhere: boto3 resolves them from the
        # pod's IRSA-injected web identity token in the cluster, or the
        # ambient AWS profile locally. Zero static keys.
        self._table = boto3.resource("dynamodb", region_name=region).Table(table_name)

    def list_restaurants(self) -> list[Restaurant]:
        items: list[dict[str, Any]] = []
        response = self._table.scan()
        items.extend(response.get("Items", []))
        while "LastEvaluatedKey" in response:  # paginate defensively
            response = self._table.scan(ExclusiveStartKey=response["LastEvaluatedKey"])
            items.extend(response.get("Items", []))
        # int() handles DynamoDB's Decimal numbers; pydantic validates the rest
        return [
            Restaurant(
                id=str(i["id"]),
                name=str(i["name"]),
                style=str(i["style"]),
                address=str(i["address"]),
                vegetarian=bool(i["vegetarian"]),
                open_hour=int(i["open_hour"]),
                close_hour=int(i["close_hour"]),
            )
            for i in items
        ]

    def ping(self) -> bool:
        try:
            self._table.load()
            return True
        except (ClientError, BotoCoreError):
            logger.exception("DynamoDB readiness check failed")
            return False
