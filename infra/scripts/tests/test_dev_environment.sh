#!/usr/bin/env bash
# Guards what `dev` IS (specs/infra/0001-dev-environment.md).
#
# Two properties that `terraform validate` cannot see and a reviewer can talk
# themselves out of:
#
#   1. dev is CHEAP BY DERIVATION. Every expensive production control is
#      switched by `local.ephemeral`, which is computed from the environment
#      name and is not a variable anyone can set. Hard-code `"REGIONAL"` or
#      `deletion_protection = true` back into database.tf and this test goes
#      red — because that is precisely the change that silently bills the
#      client for a standby nobody asked for.
#
#   2. `develop` deploys only behind a GREEN GATE. The deploy jobs must
#      `needs:` the called ship-gate workflow, inside one run. Delete that
#      edge — or swap it for a `workflow_run` trigger that fires on completion
#      regardless of conclusion — and this test goes red.
#
# Deliberately boring and grep-shaped, like test_wif_conditions.sh next to it:
# these are failures of nerve, not of logic, and a plain assertion catches them.
set -Eeuo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA="$(cd "${HERE}/../.." && pwd)"
ROOT="$(cd "${INFRA}/.." && pwd)"

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

# Passes when the pattern is NOT present — the shape of most assertions here,
# since what we are guarding against is a value creeping back in hard-coded.
refute() {
  local name="$1" pattern="$2" file="$3"
  if grep -Eq "${pattern}" "${file}"; then
    echo "    found in ${file#"${ROOT}"/}:" >&2
    grep -En "${pattern}" "${file}" >&2
    check "${name}" no
  else
    check "${name}" ok
  fi
}

assert() {
  local name="$1" pattern="$2" file="$3"
  if grep -Eq "${pattern}" "${file}"; then
    check "${name}" ok
  else
    echo "    expected to find /${pattern}/ in ${file#"${ROOT}"/}" >&2
    check "${name}" no
  fi
}

echo "dev is an accepted environment"

assert "dev is allowed by the environment validation" \
  'contains\(\["dev", "staging", "production"\]' "${INFRA}/variables.tf"
assert "domain is optional and tied to the environment" \
  'var.environment == "dev" \? var.domain == "" : var.domain != ""' "${INFRA}/variables.tf"
assert "an environments/dev.tfvars exists" '^environment *= *"dev"' "${INFRA}/environments/dev.tfvars"

echo
echo "the cheap shape is derived, not hand-set"

# `local.ephemeral` is the single switch, and it must be computed from the
# environment rather than accepted from a caller.
assert "one local derives the throwaway posture from the environment name" \
  '^  ephemeral += var.environment == "dev"$' "${INFRA}/main.tf"
refute "no variable lets a caller declare an environment ephemeral" \
  '^variable "(ephemeral|is_dev|cheap|poc)"' "${INFRA}/variables.tf"

# dev.tfvars must stay a list of facts about dev (project, image, identity) and
# never become a place where the cheap shape is assembled by hand: if the cost
# knobs are set here, an environment added by copying this file gets them wrong.
for knob in domain db_tier min_instances max_instances log_retention_days; do
  refute "dev.tfvars does not hand-set ${knob}" "^${knob} *=" "${INFRA}/environments/dev.tfvars"
done

echo
echo "the expensive database controls are conditional"

refute "availability_type is not hard-coded" 'availability_type *= *"' "${INFRA}/database.tf"
refute "point-in-time recovery is not hard-coded on" \
  'point_in_time_recovery_enabled *= *true' "${INFRA}/database.tf"
refute "deletion protection is not hard-coded on" \
  '^  deletion_protection *= *true' "${INFRA}/database.tf"
refute "the retained-backup count is not hard-coded" 'retained_backups *= *[0-9]' "${INFRA}/database.tf"
refute "the machine tier is not hard-coded" 'tier *= *"db-' "${INFRA}/database.tf"

# The controls that cost nothing are NOT conditional. Dev gives up durability,
# never the privacy of the data path.
assert "the database has no public IP in any environment" \
  'ipv4_enabled *= *false' "${INFRA}/database.tf"
assert "TLS is required in any environment" 'ssl_mode *= *"ENCRYPTED_ONLY"' "${INFRA}/database.tf"
assert "egress stays restricted to private ranges" \
  'egress *= *"PRIVATE_RANGES_ONLY"' "${INFRA}/run.tf"

echo
echo "the load-balancer edge is absent in dev"

# Every resource in edge.tf — not most of them. A single uncounted resource
# here is a global forwarding rule or a reserved IP billing every month.
edge_resources="$(grep -c '^resource "' "${INFRA}/edge.tf")"
edge_counted="$(grep -c '^  count = local.edge_enabled ? 1 : 0$' "${INFRA}/edge.tf")"
if [[ "${edge_resources}" -gt 0 && "${edge_resources}" -eq "${edge_counted}" ]]; then
  check "all ${edge_resources} edge resources are counted off in dev" ok
else
  echo "    ${edge_resources} resources in edge.tf, ${edge_counted} carry the count" >&2
  check "all edge resources are counted off in dev" no
fi

assert "dev does not pay for an always-on VPC connector" \
  '^  count += local.ephemeral \? 0 : 1$' "${INFRA}/network.tf"
assert "Cloud Run reaches the database directly when there is no connector" \
  'network_interfaces' "${INFRA}/run.tf"
assert "the public URL output reads the service's real address" \
  'google_cloud_run_v2_service.backend.uri' "${INFRA}/outputs.tf"

echo
echo "develop releases dev, and only behind a green gate"

CD="${ROOT}/.github/workflows/backend-cd.yaml"
CI="${ROOT}/.github/workflows/backend-ci.yaml"

assert "the ship gate is called as a job of the delivery run" \
  'uses: \./\.github/workflows/backend-ci\.yaml' "${CD}"
assert "the ship gate accepts being called" '^  workflow_call:' "${CI}"
# The repository-wide gate is called too. Secret scanning moved out of
# backend-ci into repo-ci so that a client-only pull request is scanned; without
# this edge that move would have taken gitleaks off the path to production,
# which is the reverse of the finding it closed.
assert "the repository-wide gate is called as a job of the delivery run" \
  'uses: \./\.github/workflows/repo-ci\.yaml' "${CD}"
assert "the repository-wide gate accepts being called" \
  '^  workflow_call:' "${ROOT}/.github/workflows/repo-ci.yaml"
assert "the image build waits for both gates" '^    needs: \[ci, repo, settings\]$' "${CD}"
assert "the deploy waits for both gates" '^    needs: \[ci, repo, settings, publish\]$' "${CD}"
assert "a non-main ref releases dev" '^            environment=dev$' "${CD}"
refute "staging is no longer a deploy target" '^            environment=staging$' "${CD}"
assert "main still releases production" '^            environment=production$' "${CD}"
assert "production still deploys behind its Environment approval" \
  'name: \$\{\{ needs.settings.outputs.environment \}\}' "${CD}"

# The run must not be able to end green while a job it depends on failed,
# was cancelled, or was skipped because the gate went red.
assert "a run with any failed, cancelled or skipped job is red" \
  "contains\(needs\.\*\.result, 'skipped'\)" "${CD}"

echo
echo "the client ships the same way, and only behind a green gate"

# Two deployables, one delivery shape. The A2UI client goes to Firebase
# Hosting rather than Cloud Run (spec frontend/0017), and every property that
# makes the backend's pipeline safe is a property of THIS one or it is not
# safe: a called gate rather than a completion trigger, `needs:` edges, an
# Environment for the production approval, a run that cannot end green while a
# job it depends on was skipped, and a button rather than a push.
FCD="${ROOT}/.github/workflows/frontend-cd.yaml"
FCI="${ROOT}/.github/workflows/frontend-ci.yaml"

assert "the frontend gate is called as a job of the client's delivery run" \
  'uses: \./\.github/workflows/frontend-ci\.yaml' "${FCD}"
assert "the frontend gate accepts being called" '^  workflow_call:' "${FCI}"
assert "the repository-wide gate is called by the client's delivery run too" \
  'uses: \./\.github/workflows/repo-ci\.yaml' "${FCD}"
assert "the bundle build waits for both gates" \
  '^    needs: \[ci, repo, settings\]$' "${FCD}"
assert "the client deploy waits for both gates and the bundle" \
  '^    needs: \[ci, repo, settings, publish\]$' "${FCD}"
assert "a non-main ref publishes the client to dev" '^            environment=dev$' "${FCD}"
assert "main publishes the client to production" \
  '^            environment=production$' "${FCD}"
assert "the client deploy is behind its Environment approval" \
  'name: \$\{\{ needs.settings.outputs.environment \}\}' "${FCD}"
assert "a client run with any failed, cancelled or skipped job is red" \
  "contains\(needs\.\*\.result, 'skipped'\)" "${FCD}"
refute "no push trigger — merging to develop publishes no client" '^  push:$' "${FCD}"
assert "the client deploy is a button" '^  workflow_dispatch:$' "${FCD}"

# Hosting has no --no-traffic revision, so the equivalent is a preview
# channel: a complete deploy of the same bytes at an address no user is sent
# to. Losing either half — the preview, or reading /release.json back off the
# live origin afterwards — turns "the deploy step exited 0" back into the only
# evidence, which is the gap GGU-93 closed for the backend.
assert "the client is proven on a preview channel before it goes live" \
  'firebase hosting:channel:deploy' "${FCD}"
assert "the live origin is asked which build it serves" \
  './frontend/tool/verify_release.sh' "${FCD}"
assert "the bundle carries the identity that check reads" \
  'build/web/release.json' "${ROOT}/frontend/tool/build_web.sh"

# One compile, one set of bytes. Re-compiling in the deploy job would mean the
# artifact the run verified is not the artifact it released — the identity
# argument backend-cd makes by deploying an image BY DIGEST.
assert "the deploy job takes the bytes the publish job built" \
  'actions/download-artifact' "${FCD}"

echo
echo "delivery is manual, and the PR gate still covers what the push gate used to"

# Merging must build and deploy nothing: the TL asked for a button, not a
# pipeline that spends on every merge. `refute` is the whole assertion here —
# a `push:` trigger creeping back is exactly the regression to catch.
refute "no push trigger — merging to develop deploys nothing" '^  push:$' "${CD}"
assert "the deploy is a button" '^  workflow_dispatch:$' "${CD}"

# Removing the push trigger removed the run that used to gate a hand-edited
# frozen contract on `develop`. That coverage is not lost: `develop` is branch
# protected, so every change arrives through a pull request, and backend-ci's
# pull_request paths still name the contract and the gate definition itself.
assert "a hand-edited frozen contract still starts the gate on a PR" \
  '^      - "docs/catalog/\*\*"$' "${CI}"
assert "editing the gate definition still starts the gate on a PR" \
  '^      - "\.github/workflows/backend-ci\.yaml"$' "${CI}"

echo
echo "one warm instance everywhere, dev included"

# The one place dev does not take the cheap option (GGU-29 AC-5). `coalesce`
# with a bare 1 rather than a ternary is the assertion: a ternary here would
# mean someone reintroduced a dev-specific zero.
assert "dev keeps an instance warm for the demo" \
  '^  min_instances = coalesce\(var\.min_instances, 1\)$' "${ROOT}/infra/main.tf"
refute "no environment derives min_instances = 0" \
  'min_instances = coalesce\(var\.min_instances, local\.ephemeral \? 0' "${ROOT}/infra/main.tf"

echo
echo "every deployable environment name is one the backend will accept"

# The one check neither side can make alone. `infra/variables.tf` decides what
# a deployment may be CALLED; `backend/src/app/core/config.py` decides what the
# process will ACCEPT being called. Both were internally consistent and nothing
# read both, so `dev` existed as an environment for which the container died at
# startup on a ValidationError — after the infrastructure had been applied.
# `terraform validate` cannot see Python and `make gate` cannot see Terraform;
# this is the seam, so the assertion lives here.
TFVARS_ENVS="$(sed -n 's/.*contains(\[\(.*\)\], var.environment).*/\1/p' \
  "${ROOT}/infra/variables.tf" | tr -d '" ' | tr ',' '\n' | grep .)"
PY_ENVS="$(sed -n 's/^Environment = Literal\[\(.*\)\]$/\1/p' \
  "${ROOT}/backend/src/app/core/config.py" | tr -d '" ' | tr ',' '\n' | grep .)"

[[ -n "${TFVARS_ENVS}" ]] || { echo "  FAIL  could not read environments from variables.tf"; FAILED=$((FAILED + 1)); }
[[ -n "${PY_ENVS}" ]] || { echo "  FAIL  could not read the Environment literal from config.py"; FAILED=$((FAILED + 1)); }

while read -r env; do
  [[ -z "${env}" ]] && continue
  if grep -qx "${env}" <<< "${PY_ENVS}"; then
    echo "  ok    '${env}' is deployable and the backend accepts it"
    PASSED=$((PASSED + 1))
  else
    echo "  FAIL  '${env}' is a deployable environment that the backend would reject at startup"
    echo "        add it to Environment in backend/src/app/core/config.py"
    FAILED=$((FAILED + 1))
  fi
done <<< "${TFVARS_ENVS}"

echo
echo "the schema moves before anything serves the new image"

SCRIPT="${ROOT}/infra/scripts/deploy_cloud_run.sh"
RUNTF="${ROOT}/infra/run.tf"

# Until 2026-09-20 nothing ran migrations at all — not the pipeline, not
# Terraform, not the container — and `/readyz` hid it by proving the
# connection rather than the schema. These assertions are the reason that
# cannot come back silently.
assert "a migration job exists" '^resource "google_cloud_run_v2_job" "migrate"' "${RUNTF}"
assert "it runs alembic, not the app" \
  'command = \["alembic", "upgrade", "head"\]' "${RUNTF}"
assert "a failed migration is not retried blindly" 'max_retries     = 0 #' "${RUNTF}"
assert "the deploy runs migrations" 'if ! migrate ' "${SCRIPT}"
assert "a failed migration rolls back" \
  'migrations failed; the schema was not moved' "${SCRIPT}"

# The seed job (spec backend/0035). Two claims, and the second is the one
# worth a check: it exists, and **nothing runs it for you**. A deploy that
# quietly reseeded somebody's portfolio would be a data-loss surprise, so
# the absence from `deploy_cloud_run.sh` is asserted rather than assumed.
assert "a portfolio seed job exists" \
  '^resource "google_cloud_run_v2_job" "seed_portfolios"' "${RUNTF}"
assert "it runs the seed module, not the app" \
  'command = \["python", "-m", "app.jobs.seed_portfolios"\]' "${RUNTF}"
assert "its audience is an overridable argument list" \
  '^        args    = var.seed_portfolio_owners$' "${RUNTF}"
if grep -q "seed_portfolios\|seed-portfolios" "${SCRIPT}"; then
  echo "  FAIL  the deploy must not run the seed job — it is a human's command"
  FAILED=$((FAILED + 1))
else
  check "the deploy never seeds on its own" ok
fi

# The ordering assertion, and the only one that really matters: migrations
# must come BEFORE the traffic shift. A line-number comparison is crude, but
# it is exactly the property — after the shift, requests meet a schema the
# running code does not expect.
migrate_line="$(grep -nF 'if ! migrate "' "${SCRIPT}" | head -1 | cut -d: -f1)"
# shellcheck disable=SC2016  # the literal `${revision}` is what we search for
shift_line="$(grep -nF 'shift_traffic "${revision}"' "${SCRIPT}" | tail -1 | cut -d: -f1)"
if [[ -n "${migrate_line}" && -n "${shift_line}" && "${migrate_line}" -lt "${shift_line}" ]]; then
  echo "  PASS  migrations run before the traffic shift (${migrate_line} < ${shift_line})"
  PASSED=$((PASSED + 1))
else
  echo "  FAIL  migrations must run BEFORE the traffic shift"
  echo "        migrate at line ${migrate_line:-?}, shift at line ${shift_line:-?}"
  FAILED=$((FAILED + 1))
fi

echo
echo "${PASSED} passed, ${FAILED} failed"
[[ "${FAILED}" -eq 0 ]]
