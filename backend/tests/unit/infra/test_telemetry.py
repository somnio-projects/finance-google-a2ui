import pytest
from pytest_mock import MockerFixture

from app.infra.telemetry.factory import build_error_reporter
from app.infra.telemetry.null_reporter import NullErrorReporter
from app.infra.telemetry.sentry_reporter import SentryErrorReporter
from tests.conftest import make_settings


def test_null_reporter_accepts_everything_silently() -> None:
    reporter = NullErrorReporter()
    assert reporter.capture_exception(RuntimeError("x")) is None
    assert reporter.increment("m", tags={"a": "b"}) is None
    assert reporter.increment("m") is None


def test_factory_returns_null_reporter_without_dsn() -> None:
    reporter = build_error_reporter(make_settings(), release="0.0.1")
    assert isinstance(reporter, NullErrorReporter)


def test_factory_returns_sentry_reporter_with_dsn(mocker: MockerFixture) -> None:
    init = mocker.patch(
        "app.infra.telemetry.sentry_reporter.sentry_sdk.init", autospec=True
    )
    settings = make_settings(
        sentry_dsn="https://key@o1.ingest.sentry.io/1", sentry_traces_sample_rate=0.25
    )
    reporter = build_error_reporter(settings, release="0.0.1")
    assert isinstance(reporter, SentryErrorReporter)
    kwargs = init.call_args.kwargs
    assert kwargs["dsn"] == "https://key@o1.ingest.sentry.io/1"
    assert kwargs["environment"] == "test"
    assert kwargs["release"] == "0.0.1"
    assert kwargs["traces_sample_rate"] == pytest.approx(0.25)
    assert kwargs["send_default_pii"] is False
    assert kwargs["max_request_body_size"] == "never"


def test_sentry_reporter_forwards_exception_and_breadcrumb(
    mocker: MockerFixture,
) -> None:
    mocker.patch("app.infra.telemetry.sentry_reporter.sentry_sdk.init", autospec=True)
    capture = mocker.patch(
        "app.infra.telemetry.sentry_reporter.sentry_sdk.capture_exception",
        autospec=True,
    )
    breadcrumb = mocker.patch(
        "app.infra.telemetry.sentry_reporter.sentry_sdk.add_breadcrumb", autospec=True
    )
    reporter = SentryErrorReporter(
        dsn="https://k@o.ingest.sentry.io/2",
        environment="test",
        release="r",
        traces_sample_rate=0.0,
    )
    error = ValueError("boom")
    reporter.capture_exception(error)
    reporter.increment("auth.accepted", tags={"provider": "jwt"})
    reporter.increment("bare")
    capture.assert_called_once_with(error)
    assert breadcrumb.call_args_list[0].kwargs["data"] == {"provider": "jwt"}
    assert breadcrumb.call_args_list[1].kwargs["data"] == {}
