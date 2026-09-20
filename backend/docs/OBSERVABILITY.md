# Observability

## Logs

structlog → JSON on stdout, one object per line, configured once in
`bootstrap.create_app` (`core/logging.py`). Every request binds `request_id`
into the context so all lines of a request correlate; the same id is returned
as `X-Request-ID` and stored in `audit_events`.

Keys `authorization`, `token`, `password`, `secret`, `cookie`, `api_key` are
redacted by processor even if someone logs them by mistake. Do not log emails
or other PII; log ids and fingerprints.

Events worth knowing: `startup` (with `public_base_url`), `shutdown`,
`unhandled_exception` (with traceback, before the masked 500 is returned),
`agent.turn` (one per turn: `model`, `outcome`, `duration_ms`, `iterations`,
`tool_calls` — and deliberately **no** prompt, answer or subject, spec 0006
AC-13), `agent.tool.failed` (the tool name and the exception *type*, never its
text) and `agent.tool.unknown` (a tool the model asked for that is not
registered).

## Errors and metrics — `ErrorReporter`

Code never talks to Sentry directly. It calls the injected `ErrorReporter`
(`core/protocols.py`):

- `capture_exception(exc)` — from the catch-all handler and anywhere a failure
  is swallowed on purpose.
- `increment(metric, tags=)` — counters. Current metrics:
  `auth.accepted{provider}`, `auth.rejected{code}`, `feature_flag.toggled{key,enabled}`,
  `agent.turn{model,outcome}`.

Implementations: `SentryErrorReporter` when `SENTRY_DSN` is set (environment,
release = app version, `send_default_pii=False`, request bodies never sent,
traces at `SENTRY_TRACES_SAMPLE_RATE`), otherwise `NullErrorReporter`. Because
the null object exists, call sites never check configuration — the same
mistake the Hoopis team documented in their `OBSERVABILITY.md`.

To add a backend (OpenTelemetry, Datadog): implement the Protocol in
`infra/telemetry/<name>_reporter.py`, choose it in
`infra/telemetry/factory.py`, test it with mocks like `test_telemetry.py`.

## Health

- `GET /health` — liveness. Never probes dependencies (a Gemini/DB blip must not restart the service).
- `GET /readyz` — readiness. Runs every `ReadinessProbe` (`database` today); 503 + `status: degraded` when any fails. Add probes by implementing the Protocol and passing them to `HealthService` in `bootstrap.build_container`.

Compose and the Dockerfile health-check `/health`; Cloud Run should use it as
the startup probe.

## Local

`docker compose up` reads `LOG_LEVEL` and `SENTRY_DSN` from `backend/.env`
(`LOG_LEVEL=DEBUG` and a DSN there exercise the verbose/Sentry paths locally).
