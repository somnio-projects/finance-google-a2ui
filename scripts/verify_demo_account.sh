#!/usr/bin/env bash
# Prove the reviewer account works end to end, before anyone hands it over.
#
# GGU-12. Exit 0 means the account exists, its credentials buy a real ID
# token, and that token opens the deployed backend. A NON-ZERO EXIT BEFORE
# HANDOVER MEANS DO NOT HAND OVER.
#
# ── Credential handling is a hard requirement here, not a style note ────────
#
# The password is read from the environment and never appears as an argument:
# an argument lands in `ps` output and in shell history, where it outlives the
# run. `set +x` is forced on so no tracing can leak it, and nothing here ever
# echoes it. The email IS an argument — it is not the secret.
#
# The repository is public. A credential committed here is an incident and a
# rotation, not a cleanup commit.
#
# ── Usage ──────────────────────────────────────────────────────────────────
#
#   export DEMO_PASSWORD='…'                # never on the command line
#   export FIREBASE_WEB_API_KEY='…'         # Firebase console → project settings
#   export BACKEND_URL='https://…run.app'   # defaults to the dev service
#   ./scripts/verify_demo_account.sh reviewer@example.com
#
# `FIREBASE_WEB_API_KEY` is the browser-embedded key, not a secret in the
# credential sense — but it is still not committed, because a key in a repo is
# a key nobody rotates.

set -Eeuo pipefail
set +x  # tracing must never be able to print the credential

readonly EMAIL="${1:-}"
readonly BACKEND="${BACKEND_URL:-https://finance-a2ui-dev-api-crqogdubva-uc.a.run.app}"
readonly IDENTITY_TOOLKIT="https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword"

step=0

die() {
  echo "  FAIL  $*" >&2
  echo >&2
  echo "DO NOT HAND OVER the account until this passes." >&2
  exit 1
}

ok() {
  echo "  ok    $*"
}

require() {
  local name="$1"
  [[ -n "${!name:-}" ]] || die "${name} is not set (see the usage block in this file)"
}

[[ -n "${EMAIL}" ]] || die "usage: $0 <email>   (the password comes from DEMO_PASSWORD)"
require DEMO_PASSWORD
require FIREBASE_WEB_API_KEY

echo "verifying ${EMAIL} against ${BACKEND}"
echo

# ── 1 · the credentials buy a real ID token ────────────────────────────────
#
# This proves the account exists, is enabled, and uses email/password — all
# three at once, from the outside, exactly as the reviewer's browser will.
# The request body goes through a file descriptor rather than an argument so
# the password never reaches `ps`.
step=1
response="$(
  curl -sS -X POST "${IDENTITY_TOOLKIT}?key=${FIREBASE_WEB_API_KEY}" \
    -H 'Content-Type: application/json' \
    --data-binary @<(
      printf '{"email":"%s","password":"%s","returnSecureToken":true}' \
        "${EMAIL}" "${DEMO_PASSWORD}"
    )
)" || die "step ${step}: could not reach the Identity Toolkit"

if grep -q '"error"' <<<"${response}"; then
  # Print the reason, never the request. Firebase's messages are safe
  # (EMAIL_NOT_FOUND, INVALID_PASSWORD, USER_DISABLED) and each one points
  # somewhere different.
  reason="$(sed -n 's/.*"message": *"\([A-Z_]*\)".*/\1/p' <<<"${response}" | head -1)"
  die "step ${step}: sign-in refused — ${reason:-unknown}"
fi

token="$(sed -n 's/.*"idToken": *"\([^"]*\)".*/\1/p' <<<"${response}")"
[[ -n "${token}" ]] || die "step ${step}: no idToken in the response"
ok "step ${step} · the credentials return an ID token"

# ── 2 · the backend accepts that token ─────────────────────────────────────
#
# `/v1/me` is the smallest authenticated route: it proves the RS256 signature
# verified against the JWKS, and that `iss` and `aud` match what the service
# was configured with. A 401 here with a valid token means the backend and
# Firebase disagree about the project.
step=2
me_status="$(
  curl -sS -o /tmp/verify_me.$$ -w '%{http_code}' \
    -H "Authorization: Bearer ${token}" "${BACKEND}/v1/me"
)"
[[ "${me_status}" == "200" ]] || die "step ${step}: GET /v1/me answered ${me_status}, expected 200"
ok "step ${step} · the backend verifies the token (GET /v1/me → 200)"

# ── 3 · the account has a coherent portfolio ───────────────────────────────
#
# The reviewer's first screen is their holdings. An account that authenticates
# but has no portfolio is a demo that opens on an empty page, which is the
# failure this step exists to catch before a reviewer finds it.
step=3
views_status="$(
  curl -sS -o /tmp/verify_views.$$ -w '%{http_code}' \
    -H "Authorization: Bearer ${token}" \
    "${BACKEND}/v1/portfolios/current/views?view=holdings.allocation.v1"
)"
[[ "${views_status}" == "200" ]] || die "step ${step}: the holdings view answered ${views_status}"
grep -q '"display"' /tmp/verify_views.$$ \
  || die "step ${step}: the holdings view rendered no formatted figures"
ok "step ${step} · the portfolio renders with formatted figures"

# ── 4 · the agent surface is reachable ─────────────────────────────────────
#
# Not a full turn — that needs a model call and is UAT-4's job, which is a
# human judgement about whether the answer *looks* right. This proves the
# protocol surface authenticates, which is the part a script can settle.
step=4
a2a_status="$(
  curl -sS -o /dev/null -w '%{http_code}' -X POST "${BACKEND}/" \
    -H "Authorization: Bearer ${token}" -H 'Content-Type: application/json' \
    -d '{"jsonrpc":"2.0","id":"verify","method":"unsupported/probe"}'
)"
# JSON-RPC answers an unknown method at HTTP 200 with an error object
# (ADR-J D-3), so 200 is the pass here — a 401 would mean the token did not
# reach the agent host.
[[ "${a2a_status}" == "200" ]] || die "step ${step}: the A2A surface answered ${a2a_status}, expected 200"
ok "step ${step} · the A2A surface accepts the token"

rm -f /tmp/verify_me.$$ /tmp/verify_views.$$
echo
echo "PASS — ${EMAIL} works end to end on ${BACKEND}"
echo
echo "This settles AC-2. It does NOT settle UAT-3 to UAT-6: whether the"
echo "numbers look right, whether the surface streams rather than dumping"
echo "JSON, whether it is legible on a phone, and whether a session survives"
echo "a five-minute gap are judgements no exit code captures. Run them."
