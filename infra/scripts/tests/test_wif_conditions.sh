#!/usr/bin/env bash
# Guards the credential model of the delivery pipeline (spec 0007 AC-3).
#
# Two properties that a reviewer can forget and a grep cannot:
#   1. no long-lived service-account key exists anywhere in infra/;
#   2. the Workload Identity provider is pinned to this repository, so the
#      pool name leaking is not enough to mint a credential.
#
# This runs in pre-commit and in infra-ci. It is intentionally boring: the
# failure it prevents is someone "temporarily" adding a key resource.
set -Eeuo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA="$(cd "${HERE}/../.." && pwd)"

PASSED=0
FAILED=0

check() {
  local name="$1" result="$2"
  if [[ "${result}" == "ok" ]]; then
    echo "  PASS  ${name}"
    PASSED=$(( PASSED + 1 ))
  else
    echo "  FAIL  ${name}"
    FAILED=$(( FAILED + 1 ))
  fi
}

echo "infra credential model"

if grep -rn 'resource "google_service_account_key"' "${INFRA}" --include='*.tf' >/dev/null 2>&1; then
  echo "    a service-account key resource was found:" >&2
  grep -rn 'resource "google_service_account_key"' "${INFRA}" --include='*.tf' >&2
  check "no long-lived service-account key is declared" no
else
  check "no long-lived service-account key is declared" ok
fi

provider_file="${INFRA}/delivery.tf"
if [[ -f "${provider_file}" ]] \
  && grep -q 'attribute_condition' "${provider_file}" \
  && grep -q 'assertion.repository == ' "${provider_file}"; then
  check "the identity provider is pinned to one repository" ok
else
  check "the identity provider is pinned to one repository" no
fi

if grep -q 'issuer_uri *= *"https://token.actions.githubusercontent.com"' "${provider_file}"; then
  check "the issuer is GitHub's OIDC endpoint over TLS" ok
else
  check "the issuer is GitHub's OIDC endpoint over TLS" no
fi

# The repository condition alone would let a workflow on ANY branch mint a
# credential that deploys production. Production must also pin the ref.
if grep -q 'assertion.ref == .*refs/heads/main' "${provider_file}"; then
  check "production additionally requires the token to come from main" ok
else
  check "production additionally requires the token to come from main" no
fi

# The pipeline must never own the image or the traffic split in Terraform too:
# a later apply would undo a rollback (spec 0007 OD-6).
if grep -q 'ignore_changes' "${INFRA}/run.tf" && grep -q 'traffic,' "${INFRA}/run.tf"; then
  check "Terraform yields the image and the traffic split to the pipeline" ok
else
  check "Terraform yields the image and the traffic split to the pipeline" no
fi

echo
echo "${PASSED} passed, ${FAILED} failed"
[[ "${FAILED}" -eq 0 ]]
