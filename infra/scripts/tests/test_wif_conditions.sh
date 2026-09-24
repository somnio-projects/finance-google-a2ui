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

# 3. Every resource `deploy_cloud_run.sh` acts on is granted to the deployer.
#
# The failure this prevents actually happened (2026-09-21): the deployer held
# `roles/run.developer` on the Cloud Run **service** and nothing on the
# migration **job**, so `gcloud run jobs execute` answered
#
#   PERMISSION_DENIED: Permission 'run.jobs.get' denied on resource
#   'namespaces/.../jobs/finance-a2ui-dev-migrate'
#
# The pipeline behaved correctly — it refused to shift traffic and rolled back
# — but no deploy could ever have succeeded, and nothing said so until someone
# pressed the button. Terraform was valid the whole time: a grant that is
# absent is not a syntax error.
for resource in service job; do
  if grep -rn "google_cloud_run_v2_${resource}_iam_member" "${INFRA}" --include='*.tf' \
       | grep -q 'deployer'; then
    check "the deployer is granted on the Cloud Run ${resource} it deploys" ok
  else
    echo "    deploy_cloud_run.sh acts on a Cloud Run ${resource}, and no" >&2
    echo "    google_cloud_run_v2_${resource}_iam_member grants the deployer on one." >&2
    check "the deployer is granted on the Cloud Run ${resource} it deploys" no
  fi
done

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
