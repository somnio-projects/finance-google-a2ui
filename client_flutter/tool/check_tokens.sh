#!/usr/bin/env bash
# Gate: no raw colour literals outside the theme layer.
#
# Feature code must read colours from FinanceTokens so that a token change
# re-themes the app without editing anything under features/.
set -euo pipefail
cd "$(dirname "$0")/.."

violations=$(
  grep -rnE 'Colors\.[a-zA-Z]|Color\(0x' app/lib \
    --exclude-dir=theme \
    | grep -vE '^[^:]+:[0-9]+:\s*//' \
    || true
)

if [[ -n "$violations" ]]; then
  echo 'Raw colour literals outside app/lib/src/theme:' >&2
  echo "$violations" >&2
  exit 1
fi
echo 'check_tokens: OK'
