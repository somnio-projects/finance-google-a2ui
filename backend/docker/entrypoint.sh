#!/bin/sh
# Container entry point: apply migrations, then serve.
# RUN_MIGRATIONS=false lets a separate job own migrations in production.
set -eu

if [ "${RUN_MIGRATIONS:-true}" = "true" ]; then
  alembic upgrade head
fi

exec uvicorn app.main:app \
  --host "${HOST:-0.0.0.0}" \
  --port "${PORT:-8000}" \
  --proxy-headers \
  --forwarded-allow-ips="${FORWARDED_ALLOW_IPS:-*}" \
  --no-server-header \
  ${UVICORN_EXTRA_ARGS:-}
