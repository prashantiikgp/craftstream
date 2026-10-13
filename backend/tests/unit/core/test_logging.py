import json
import logging

from app.core.logging import CloudJsonFormatter


def test_json_lines_carry_severity_and_extra_fields():
    record = logging.LogRecord("app.x", logging.WARNING, __file__, 1, "upload %s", ("done",), None)
    record.product_id = "abc"
    entry = json.loads(CloudJsonFormatter().format(record))
    assert entry["severity"] == "WARNING"
    assert entry["message"] == "upload done"
    assert entry["product_id"] == "abc"
