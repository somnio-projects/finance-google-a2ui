#!/bin/sh
# Container entry point: apply migrations, then serve.
# RUN_MIGRATIONS=false lets a separate job own migrations in production.
set -eu

if [ "${RUN_MIGRATIONS:-true}" = "true" ]; then
  alembic upgrade head
fi

# shellcheck disable=SC2086 # UVICORN_EXTRA_ARGS is a list of arguments, not one
# argument: quoting it would hand uvicorn a single empty string when it is unset
# and one run-together token when it is not. Word splitting here is the feature.
exec uvicorn app.main:app \
  --host "${HOST:-0.0.0.0}" \
  --port "${PORT:-8000}" \
  --proxy-headers \
  --forwarded-allow-ips="${FORWARDED_ALLOW_IPS:-*}" \
  --no-server-header \
  ${UVICORN_EXTRA_ARGS:-}
