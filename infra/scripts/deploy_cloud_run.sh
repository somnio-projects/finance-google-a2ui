#!/usr/bin/env bash
# Deploy one backend image to Cloud Run, verify it, and roll back if it is not
# healthy (spec 0007 AC-1, AC-4, AC-5).
#
# The risky part of delivery lives here rather than inline in a workflow for
# one reason: a shell script can be run against a stub `gcloud` and therefore
# TESTED. A rollback path that has never executed is not a rollback path.
#
# Order matters and is the reason traffic never lands on a broken revision:
#   1. create the revision with --no-traffic; its startup runs the migrations
#      and Cloud Run only reports it Ready once the startup probe on /readyz
#      passes (infra/run.tf)
#   2. assert that revision's Ready condition is True — explicitly, because a
#      deploy that "succeeded" without a ready revision must not take traffic
#   2b. point EVERY Cloud Run job labelled `image-owner=delivery` at the same
#      image, then run the migration — a job the deploy never executes
#      (`purge-audit`, monthly on a schedule; `seed-portfolios`, by hand) is
#      still on the released build when somebody or something does run it
#   3. only then shift 100 % of traffic to it
#   4. verify PUBLIC_URL/health reports exactly the release we deployed
#   5. on any failure, put traffic back on the revision that was serving before
#
# Why the post-shift check uses PUBLIC_URL rather than a hostname this script
# works out for itself: what is reachable differs per environment, and the
# script must not have to know which one it is in. In staging and production
# the service's ingress is INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER
# (infra/run.tf), so the *.run.app URLs are unreachable from a GitHub-hosted
# runner and the load balancer domain is the only address that resolves. In
# dev there is no load balancer, ingress is open, and PUBLIC_URL is the
# service's own run.app URL — which is exactly why dev's ingress is open
# (specs/infra/0001-dev-environment.md AC-6). Either way the caller passes one
# address, /health is unauthenticated by contract, and the verify-then-roll-
# back sequence below is identical.
#
# The pre-shift check stays the revision's Ready condition rather than an HTTP
# probe in every environment: a revision with no traffic has no address of its
# own to probe.
#
# Usage:
#   deploy_cloud_run.sh
# Environment:
#   SERVICE, REGION, PROJECT               required always
#   IMAGE, RELEASE, PUBLIC_URL             required when deploying
#   ROLLBACK_TO            deploy nothing, just move traffic to that revision
#   READY_RETRIES          health attempts after the shift (default 10)
#   READY_DELAY_SECONDS    delay between attempts (default 6)
#   GITHUB_STEP_SUMMARY    when set, a summary table is appended to it
set -Eeuo pipefail

READY_RETRIES="${READY_RETRIES:-10}"
READY_DELAY_SECONDS="${READY_DELAY_SECONDS:-6}"

# The one job this script also EXECUTES. Derived from the service name exactly
# as Terraform derives both from `local.name` (infra/run.tf). Every other job
# is discovered by label — see delivery_jobs() — and this one is discovered the
# same way; the name is kept only so the execute call and the anti-vacuity
# check below can name it.
MIGRATE_JOB="${SERVICE:+${SERVICE%-api}-migrate}"

die() {
  echo "::error::$*" >&2
  exit 1
}

require_env() {
  for name in "$@"; do
    [[ -n "${!name:-}" ]] || die "missing required environment variable: ${name}"
  done
}

gcloud_run() {
  gcloud run "$@" --project="${PROJECT}" --region="${REGION}" --quiet
}

# Every Cloud Run job this environment owns, read from the label Terraform
# puts on it (`image-owner=delivery`, infra/run.tf). Derived, never
# enumerated: a list of job names in this file is a list somebody has to
# remember to extend, and the one time it mattered nobody did — `seed-portfolios`
# was left running a floating tag for its whole life (spec infra/0004).
# The delivery-owned jobs, or a diagnosis of why the question could not be
# answered.
#
# `2>/dev/null || true` used to be here, and it turned a **permission denial**
# into an empty list — so the caller reported "no job carries the label" and
# told the operator to run `terraform apply`, which had already run and was
# not the problem. The first real deploy after spec `infra/0004` failed
# exactly that way. An error that answers the wrong question is worse than no
# check: keep stderr, and let the caller tell the two apart.
delivery_jobs() {
  gcloud_run jobs list --filter="metadata.labels.image-owner=delivery" \
    --format='value(metadata.name)'
}

serving_revision() {
  gcloud_run services describe "${SERVICE}" \
    --format='value(status.traffic[0].revisionName)' 2>/dev/null || true
}

shift_traffic() {
  local revision="$1"
  gcloud_run services update-traffic "${SERVICE}" --to-revisions="${revision}=100"
}

# Reads one field out of a JSON document on stdin. Kept in one place so the
# script never parses JSON with grep.
json_field() {
  python3 -c '
import json, sys
try:
    document = json.load(sys.stdin)
except ValueError:
    sys.exit(1)
for key in sys.argv[1:]:
    if not isinstance(document, dict):
        sys.exit(1)
    document = document.get(key)
print("" if document is None else document)
' "$@"
}

# True only when the revision reports a Ready condition of "True".
revision_is_ready() {
  local revision="$1" conditions
  conditions="$(gcloud_run revisions describe "${revision}" --format=json 2>/dev/null || true)"
  [[ -n "${conditions}" ]] || return 1
  printf '%s' "${conditions}" | python3 -c '
import json, sys
try:
    revision = json.load(sys.stdin)
except ValueError:
    sys.exit(1)
ready = [c for c in revision.get("status", {}).get("conditions", []) if c.get("type") == "Ready"]
sys.exit(0 if ready and ready[0].get("status") == "True" else 1)
'
}

# Probes a URL until it answers 200, or gives up. Prints the last body.
probe() {
  local url="$1" attempt=1 body status
  local capture="${TMPDIR:-/tmp}/probe.$$"
  while (( attempt <= READY_RETRIES )); do
    status="$(curl -sS -o "${capture}" -w '%{http_code}' --max-time 10 "${url}" || echo 000)"
    body="$(cat "${capture}" 2>/dev/null || true)"
    rm -f "${capture}"
    if [[ "${status}" == "200" ]]; then
      echo "${body}"
      return 0
    fi
    echo "probe ${url} attempt ${attempt}/${READY_RETRIES} -> ${status}" >&2
    attempt=$(( attempt + 1 ))
    (( attempt <= READY_RETRIES )) && sleep "${READY_DELAY_SECONDS}"
  done
  return 1
}

summary() {
  [[ -n "${GITHUB_STEP_SUMMARY:-}" ]] || return 0
  printf '%s\n' "$@" >> "${GITHUB_STEP_SUMMARY}"
}

# Puts traffic back where it was and fails the run. Never silently succeeds:
# a deploy that could not be verified is a failed deploy, not a warning.
rollback() {
  local previous="$1" failed="$2" reason="$3"
  echo "::error::${reason}" >&2
  if [[ -n "${previous}" && "${previous}" != "${failed}" ]]; then
    echo "restoring traffic to ${previous}"
    shift_traffic "${previous}"
    summary "**Rolled back** \`${SERVICE}\` to \`${previous}\` — ${reason}."
  else
    summary "**Deploy failed** on \`${SERVICE}\` — ${reason}. No previous revision to restore."
  fi
  exit 1
}

# Points every delivery-owned job at the image being released, BEFORE any of
# them runs and before traffic moves. `gcloud run jobs execute` runs whatever
# image the job carries, and Terraform ignores that field on all of them so
# this pipeline can own it — this function is the owner.
#
# An empty list is a FAILURE, not a no-op. It is exactly what a missing label
# looks like (measured: `gcloud run jobs list --filter=…image-owner=delivery`
# answers with a warning and exit 0 when nothing carries it), and a deploy that
# quietly updated nothing is the defect this closes, one level up. Same
# anti-vacuity idiom as scripts/check_shell.sh.
point_jobs_at_image() {
  local jobs job found listing status
  listing="$(delivery_jobs 2>&1)"
  status=$?

  # Asking and being refused is not the same as asking and being told none.
  if [[ ${status} -ne 0 ]]; then
    echo "::error::could not list Cloud Run jobs in ${PROJECT}/${REGION}" >&2
    echo "  gcloud said: ${listing}" >&2
    echo "  a denial here is an IAM gap, not a missing label: the deployer" >&2
    echo "  needs run.jobs.list (roles/run.viewer) and run.developer on each" >&2
    echo "  delivery-owned job — infra/delivery.tf" >&2
    return 1
  fi
  jobs="${listing}"

  if [[ -z "${jobs//[[:space:]]/}" ]]; then
    echo "::error::no Cloud Run job carries image-owner=delivery in ${PROJECT}/${REGION}" >&2
    echo "  run \`terraform apply\` for this environment: the label is set in infra/run.tf" >&2
    return 1
  fi

  # The migration is the one job this script also EXECUTES, so its absence
  # means the filter is answering about the wrong thing — a silently partial
  # list, which is the failure mode a bare count would miss.
  if ! grep -qx "${MIGRATE_JOB}" <<< "${jobs}"; then
    echo "::error::${MIGRATE_JOB} is not in the delivery-owned job list:" >&2
    while read -r found; do echo "  ${found}" >&2; done <<< "${jobs}"
    return 1
  fi

  while read -r job; do
    [[ -n "${job}" ]] || continue
    echo "pointing ${job} at the released image"
    gcloud_run jobs update "${job}" --image="${IMAGE}" || return 1
  done <<< "${jobs}"
  return 0
}

main() {
  require_env SERVICE REGION PROJECT

  local previous
  previous="$(serving_revision)"

  if [[ -n "${ROLLBACK_TO:-}" ]]; then
    echo "rolling back ${SERVICE} to ${ROLLBACK_TO}"
    shift_traffic "${ROLLBACK_TO}"
    summary "Rolled \`${SERVICE}\` back to \`${ROLLBACK_TO}\`."
    return 0
  fi

migrate() {
  # Runs the schema forward before anything serves the new image.
  #
  # Order matters and is the whole point: the job runs on the image being
  # released, and it runs **before** the traffic shift. A migration after the
  # shift would mean requests hitting a schema the code does not expect; a
  # migration at container start would mean two booting instances racing
  # through it, which Alembic's version table does not guard.
  #
  # A failure here is a hard stop with traffic untouched — the previous
  # revision keeps serving the schema it was written for.
  local job="$1"
  echo "running migrations with the released image"

  # `gcloud run jobs execute` runs whatever image the JOB carries, and
  # Terraform ignores that field on purpose (infra/run.tf) so this pipeline
  # can own it. Nothing owned it: the job kept the image it was created with
  # while the service moved on, and the comment above — "the job runs on the
  # image being released" — was false for every deploy after the first.
  #
  # It stayed invisible because the service also carries `RUN_MIGRATIONS=true`
  # and migrates at container start, so the schema did move; the job then hit
  # a version its own (older) code had never heard of and failed with
  # `Can't locate revision identified by '<rev>'`, which reads like a broken
  # migration chain and is not one. That belt stays on (spec infra/0003 OD-2):
  # removing it would boot the revision on the old schema, and the bootstrap
  # of the admin registry runs at boot.
  #
  # Setting the image is no longer done here. `point_jobs_at_image` above does
  # it for EVERY delivery-owned job, because doing it in the step that happens
  # to execute one of them is how the other two were missed (spec infra/0004).
  if ! gcloud run jobs execute "${job}" \
    --region="${REGION}" --project="${PROJECT}" \
    --update-env-vars="APP_RELEASE=${RELEASE}" \
    --wait 2>&1; then
    return 1
  fi
  return 0
}

  require_env IMAGE RELEASE PUBLIC_URL

  echo "deploying ${IMAGE} to ${SERVICE} without traffic"
  if ! gcloud_run deploy "${SERVICE}" \
    --image="${IMAGE}" \
    --no-traffic \
    --update-env-vars="APP_RELEASE=${RELEASE}"; then
    # Nothing was shifted, so the previous revision is still serving. Say so
    # rather than calling update-traffic on a service we just failed to change.
    summary "**Deploy failed** on \`${SERVICE}\` — the revision was never created. \`${previous:-none}\` still serves."
    die "gcloud run deploy failed; traffic untouched"
  fi

  local revision health reported
  revision="$(gcloud_run services describe "${SERVICE}" \
    --format='value(status.latestCreatedRevisionName)')"
  [[ -n "${revision}" ]] || rollback "${previous}" "" "could not determine the created revision"

  echo "candidate revision ${revision}"

  # The gate before traffic. An unresolvable or not-ready revision is a hard
  # failure — never a reason to fall back to something reachable.
  if ! revision_is_ready "${revision}"; then
    rollback "${previous}" "${revision}" \
      "revision ${revision} did not become Ready (startup probe on /readyz)"
  fi

  # Every job first, then the schema, then traffic. Pinning the images before
  # the migration means the migration itself is covered by it, and a job this
  # script never executes (`purge-audit` runs monthly on a schedule,
  # `seed-portfolios` by hand) is still on the released build afterwards.
  if ! point_jobs_at_image; then
    rollback "${previous}" "${revision}" \
      "could not point every Cloud Run job at the released image"
  fi

  # Schema first, then traffic. See `migrate` above for why this order is the
  # one that cannot serve a half-applied schema.
  if ! migrate "${MIGRATE_JOB}"; then
    rollback "${previous}" "${revision}" "migrations failed; the schema was not moved"
  fi

  echo "shifting traffic to ${revision}"
  shift_traffic "${revision}"

  if ! health="$(probe "${PUBLIC_URL}/health")"; then
    rollback "${previous}" "${revision}" "health did not answer 200 after the traffic shift"
  fi

  reported="$(printf '%s' "${health}" | json_field version || true)"
  if [[ "${reported}" != "${RELEASE}" ]]; then
    rollback "${previous}" "${revision}" \
      "health reports release '${reported}', expected '${RELEASE}'"
  fi

  echo "deployed ${revision} (${RELEASE})"
  summary \
    "| Field | Value |" \
    "|---|---|" \
    "| Service | \`${SERVICE}\` |" \
    "| Image | \`${IMAGE}\` |" \
    "| Revision | \`${revision}\` |" \
    "| Release | \`${RELEASE}\` |" \
    "| Readiness | Ready before the traffic shift |" \
    "| Verified at | ${PUBLIC_URL}/health |"
}

main "$@"
