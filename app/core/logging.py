"""Structured JSON logging with sensitive-field masking.

Logs are treated as sensitive data (see docs/architecture.md):
masking happens HERE, in-process, before a log line ever reaches
stdout — collectors (Fluent Bit) and storage (CloudWatch) never
see raw secrets.
"""

import json
import logging
import sys
from datetime import datetime, timezone
from typing import Any

# Case-insensitive key names whose values are always masked.
SENSITIVE_KEYS = {
    "password",
    "passwd",
    "secret",
    "token",
    "access_token",
    "refresh_token",
    "authorization",
    "api_key",
    "x-api-key",
    "cookie",
    "set-cookie",
    "session",
    "credit_card",
    "ssn",
}

MASK = "***MASKED***"


def mask_sensitive(value: Any) -> Any:
    """Recursively mask values of sensitive keys in dicts/lists."""
    if isinstance(value, dict):
        return {
            k: MASK if k.lower() in SENSITIVE_KEYS else mask_sensitive(v)
            for k, v in value.items()
        }
    if isinstance(value, list):
        return [mask_sensitive(item) for item in value]
    return value


class JsonFormatter(logging.Formatter):
    """One JSON object per line — queryable in CloudWatch Logs Insights."""

    def format(self, record: logging.LogRecord) -> str:
        payload: dict[str, Any] = {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "level": record.levelname,
            "logger": record.name,
            "message": record.getMessage(),
        }
        # Structured context passed via `extra={"extra_fields": {...}}`
        extra = getattr(record, "extra_fields", None)
        if isinstance(extra, dict):
            payload.update(mask_sensitive(extra))
        if record.exc_info:
            payload["exception"] = self.formatException(record.exc_info)
        return json.dumps(payload, default=str)


def configure_logging(level: str = "INFO") -> None:
    """Route all logging through the JSON formatter on stdout.

    stdout (not files) is the 12-factor/Kubernetes contract: the container
    runtime captures it and the node-level collector ships it.
    """
    handler = logging.StreamHandler(sys.stdout)
    handler.setFormatter(JsonFormatter())
    root = logging.getLogger()
    root.handlers = [handler]
    root.setLevel(level.upper())
    # uvicorn's own access log is redundant with our request middleware
    logging.getLogger("uvicorn.access").disabled = True
