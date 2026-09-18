import logging

import pytest
import structlog

from app.core.logging import configure_logging, get_logger, redact_sensitive


def test_redact_sensitive_masks_known_keys_only() -> None:
    event = {"authorization": "Bearer x", "Token": "abc", "user": "u1"}
    result = redact_sensitive(None, "info", event)
    assert result["authorization"] == "[REDACTED]"
    assert result["Token"] == "[REDACTED]"
    assert result["user"] == "u1"


def test_configure_logging_sets_root_level_and_json_output(
    capsys: pytest.CaptureFixture[str],
) -> None:
    configure_logging("WARNING")
    assert logging.getLogger().level == logging.WARNING
    log = get_logger("test")
    log.info("dropped")  # below level
    log.warning("kept", password="hunter2")
    out = capsys.readouterr().out
    assert '"event": "kept"' in out
    assert "hunter2" not in out
    assert "dropped" not in out
    assert structlog.is_configured()
