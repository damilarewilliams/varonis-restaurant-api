#!/usr/bin/env python3
"""Seed the DynamoDB restaurants table with the sample catalog.

The same data the in-memory repository serves locally, so behavior is
identical across backends. Idempotent: put_item overwrites by id.

Usage:
    python scripts/seed_dynamodb.py --table varonis-restaurant-api-dev-restaurants
    # table defaults to $APP_DYNAMODB_TABLE if set

Credentials come from the ambient AWS config (profile/SSO locally,
IRSA in-cluster) - never from arguments or code.
"""

import argparse
import os
import sys

import boto3

# Import the canonical sample data from the app package so the two
# backends can never drift apart.
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from app.repositories.memory import SAMPLE_RESTAURANTS  # noqa: E402


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--table",
        default=os.environ.get("APP_DYNAMODB_TABLE"),
        help="DynamoDB table name (default: $APP_DYNAMODB_TABLE)",
    )
    parser.add_argument(
        "--region",
        default=os.environ.get("APP_AWS_REGION", "us-east-1"),
        help="AWS region (default: $APP_AWS_REGION or us-east-1)",
    )
    args = parser.parse_args()

    if not args.table:
        parser.error("--table required (or set APP_DYNAMODB_TABLE)")

    table = boto3.resource("dynamodb", region_name=args.region).Table(args.table)
    for restaurant in SAMPLE_RESTAURANTS:
        table.put_item(Item=restaurant.model_dump())
        print(f"seeded {restaurant.id}: {restaurant.name}")

    count = table.scan(Select="COUNT")["Count"]
    print(f"done - table {args.table} now holds {count} items")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
