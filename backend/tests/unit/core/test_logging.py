import json
import logging

from app.core.logging import CloudJsonFormatter, PlainFormatter, configure_logging


def test_json_lines_carry_severity_and_extra_fields():
    record = logging.LogRecord("app.x", logging.WARNING, __file__, 1, "upload %s", ("done",), None)
    record.product_id = "abc"
    entry = json.loads(CloudJsonFormatter().format(record))
    assert entry["severity"] == "WARNING"
    assert entry["message"] == "upload done"
    assert entry["product_id"] == "abc"


def test_each_mode_gets_its_format_from_app_yml():
    root = logging.getLogger("app")
    try:
        configure_logging("gcp")
        assert isinstance(root.handlers[0].formatter, CloudJsonFormatter)
        assert root.level == logging.INFO  # the default level from app.yml
        configure_logging("local", "debug")
        assert isinstance(root.handlers[0].formatter, PlainFormatter)
        assert root.level == logging.DEBUG
    finally:
        configure_logging("local")
