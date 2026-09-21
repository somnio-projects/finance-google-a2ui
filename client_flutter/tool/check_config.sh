#!/usr/bin/env bash
# Gate: no hardcoded endpoint URLs outside the config layer.
#
# The backend URL comes from AppConfig (--dart-define). Ignored: comment
# lines (license headers) and the A2UI catalog id, which is a spec
# identifier rather than an endpoint the client connects to.
set -euo pipefail
cd "$(dirname "$0")/.."

violations=$(
  grep -rnE "'https?://" app/lib \
    --exclude-dir=config \
    | grep -vE '^[^:]+:[0-9]+:\s*//' \
    | grep -vF 'a2ui.org/specification' \
    || true
)

if [[ -n "$violations" ]]; then
  echo 'Hardcoded URLs outside app/lib/src/config:' >&2
  echo "$violations" >&2
  exit 1
fi
echo 'check_config: OK'
