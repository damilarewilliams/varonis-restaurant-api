"""Logging tests: masking correctness and JSON output shape."""

import json
import logging

from app.core.logging import MASK, JsonFormatter, mask_sensitive


def test_masks_sensitive_keys_case_insensitively():
    masked = mask_sensitive({"Password": "hunter2", "TOKEN": "abc", "name": "ok"})
    assert masked["Password"] == MASK
    assert masked["TOKEN"] == MASK
    assert masked["name"] == "ok"


def test_masks_nested_structures():
    payload = {
        "user": {"api_key": "k-123", "email": "a@b.c"},
        "items": [{"authorization": "Bearer xyz"}],
    }
    masked = mask_sensitive(payload)
    assert masked["user"]["api_key"] == MASK
    assert masked["user"]["email"] == "a@b.c"
    assert masked["items"][0]["authorization"] == MASK


def test_formatter_emits_valid_json_with_masked_extras():
    record = logging.LogRecord(
        name="test", level=logging.INFO, pathname=__file__, lineno=1,
        msg="hello", args=(), exc_info=None,
    )
    record.extra_fields = {"query": {"token": "secret-value"}, "status": 200}
    line = JsonFormatter().format(record)
    payload = json.loads(line)  # must be one valid JSON object
    assert payload["message"] == "hello"
    assert payload["query"]["token"] == MASK
    assert "secret-value" not in line
    assert {"timestamp", "level", "logger"} <= set(payload)
