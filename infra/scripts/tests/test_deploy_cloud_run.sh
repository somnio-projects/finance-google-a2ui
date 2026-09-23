#!/usr/bin/env bash
# Behavioural tests for deploy_cloud_run.sh (spec 0007 AC-1, AC-4, AC-5).
#
# The script is exercised against a STUB `gcloud` and a STUB `curl` placed on
# PATH, so the deploy, the readiness gate and — the point of the exercise —
# the ROLLBACK all really execute, with no Google Cloud account involved.
#
# Mutation check: delete the `shift_traffic "${previous}"` line from the
# script's rollback() and the rollback assertions must go red. If they still
# pass, the rollback is not being tested.
set -Eeuo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="${HERE}/../deploy_cloud_run.sh"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/deploy-cloud-run-test.XXXXXX")"
trap 'rm -rf "${WORK}"' EXIT

PASSED=0
FAILED=0

# SCENARIO drives both stubs:
#   happy             everything works
#   deploy_fails      `gcloud run deploy` exits non-zero
#   no_revision       the service reports no latestCreatedRevisionName
#   not_ready         the revision never reaches Ready=True
#   health_fail       /health never answers 200 after the shift
#   release_mismatch  /health answers 200 but reports another release
#   release_prefix    /health reports a release the expected one is a PREFIX of
#   job_update_fails  `gcloud run jobs update` (the job's image) exits non-zero
#   migrate_fails     `gcloud run jobs execute` exits non-zero
#   no_delivery_jobs  `gcloud run jobs list` finds nothing carrying the label
#   jobs_list_denied  the deployer may not list jobs at all — a DIFFERENT
#                     answer from "none carry the label", and the one the
#                     first real deploy actually hit
#   jobs_without_migrate  the list comes back, but without the migrate job
make_stubs() {
  local scenario="$1"
  mkdir -p "${WORK}/bin"

  cat > "${WORK}/bin/gcloud" <<'STUB'
#!/usr/bin/env bash
echo "$*" >> "${CALL_LOG}"

if [[ "$*" == *"run deploy"* ]]; then
  if [[ "${SCENARIO}" == "deploy_fails" ]]; then echo "deploy exploded" >&2; exit 1; fi
  exit 0
fi

# The delivery-owned job list, discovered by label (spec infra/0004). Three
# jobs, of which only the migration is ever executed — the other two are the
# ones a name-by-name pipeline forgot.
if [[ "$*" == *"jobs list"* ]]; then
  case "${SCENARIO}" in
    no_delivery_jobs)     : ;;
    jobs_list_denied)
      echo "ERROR: (gcloud.run.jobs.list) PERMISSION_DENIED: Permission 'run.jobs.list' denied" >&2
      exit 1
      ;;
    jobs_without_migrate) printf 'api-purge-audit\napi-seed-portfolios\n' ;;
    *)                    printf 'api-migrate\napi-purge-audit\napi-seed-portfolios\n' ;;
  esac
  exit 0
fi

if [[ "$*" == *"jobs update"* ]]; then
  if [[ "${SCENARIO}" == "job_update_fails" ]]; then echo "no such job" >&2; exit 1; fi
  exit 0
fi

if [[ "$*" == *"jobs execute"* ]]; then
  if [[ "${SCENARIO}" == "migrate_fails" ]]; then echo "alembic exploded" >&2; exit 1; fi
  exit 0
fi

if [[ "$*" == *"revisions describe"* ]]; then
  if [[ "${SCENARIO}" == "not_ready" ]]; then
    echo '{"status":{"conditions":[{"type":"Ready","status":"False","message":"probe failed"}]}}'
  else
    echo '{"status":{"conditions":[{"type":"Active","status":"True"},{"type":"Ready","status":"True"}]}}'
  fi
  exit 0
fi

for arg in "$@"; do
  case "${arg}" in
    --format=value\(status.traffic\[0\].revisionName\)) echo "api-00007-old"; exit 0 ;;
    --format=value\(status.latestCreatedRevisionName\))
      if [[ "${SCENARIO}" == "no_revision" ]]; then echo ""; exit 0; fi
      echo "api-00008-new"; exit 0 ;;
  esac
done
exit 0
STUB

  cat > "${WORK}/bin/curl" <<'STUB'
#!/usr/bin/env bash
# Parse only what deploy_cloud_run.sh actually passes.
out=""; url=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -o) out="$2"; shift 2 ;;
    -w|--max-time) shift 2 ;;
    -sS) shift ;;
    *) url="$1"; shift ;;
  esac
done
body=""; status="200"
case "${url}" in
  */health)
    case "${SCENARIO}" in
      health_fail) status="500"; body="boom" ;;
      release_mismatch) body='{"status":"ok","version":"0.1.0+stale00"}' ;;
      release_prefix)   body='{"status":"ok","version":"0.1.0+a1b2c3d-dirty"}' ;;
      *) body="{\"status\":\"ok\",\"version\":\"${RELEASE}\"}" ;;
    esac ;;
  *) status="404"; body="not found" ;;
esac
if [[ -n "${out}" ]]; then printf '%s' "${body}" > "${out}"; fi
printf '%s' "${status}"
exit 0
STUB

  cat > "${WORK}/bin/sleep" <<'STUB'
#!/usr/bin/env bash
exit 0
STUB

  chmod +x "${WORK}/bin/gcloud" "${WORK}/bin/curl" "${WORK}/bin/sleep"
  export SCENARIO="${scenario}"
}

run_deploy() {
  CALL_LOG="${WORK}/calls.log"
  : > "${CALL_LOG}"
  : > "${WORK}/summary.md"
  export CALL_LOG
  PATH="${WORK}/bin:${PATH}" \
  SERVICE=api REGION=us-central1 PROJECT=proj \
  IMAGE="us-central1-docker.pkg.dev/proj/finance/backend@sha256:abc" \
  RELEASE="0.1.0+a1b2c3d" \
  PUBLIC_URL="https://api.example.test" \
  READY_RETRIES=2 READY_DELAY_SECONDS=0 \
  GITHUB_STEP_SUMMARY="${WORK}/summary.md" \
    bash "${SCRIPT}"
}

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

assert_contains() {
  local name="$1" haystack="$2" needle="$3"
  if [[ "${haystack}" == *"${needle}"* ]]; then check "${name}" ok; else check "${name}" no; fi
}

assert_not_contains() {
  local name="$1" haystack="$2" needle="$3"
  if [[ "${haystack}" != *"${needle}"* ]]; then check "${name}" ok; else check "${name}" no; fi
}

assert_exit_zero() {
  if run_deploy > "${WORK}/out.txt" 2>&1; then check "$1" ok; else check "$1" no; fi
}

assert_exit_nonzero() {
  if run_deploy > "${WORK}/out.txt" 2>&1; then check "$1" no; else check "$1" ok; fi
}

SHIFT_NEW="--to-revisions=api-00008-new=100"
SHIFT_OLD="--to-revisions=api-00007-old=100"

# ---------------------------------------------------------------- case 1
echo "case 1 · a ready revision takes traffic and the run succeeds (AC-1, AC-5)"
make_stubs happy
assert_exit_zero "exits 0"
calls="$(cat "${WORK}/calls.log")"
assert_contains "deploys the image"          "${calls}" "run deploy api --image="
assert_contains "deploys without traffic"    "${calls}" "--no-traffic"
assert_contains "injects the release"        "${calls}" "APP_RELEASE=0.1.0+a1b2c3d"
assert_contains "checks the revision's Ready condition" "${calls}" "revisions describe api-00008-new"
assert_contains "discovers the jobs by label, naming none of them" "${calls}" \
  "jobs list --filter=metadata.labels.image-owner=delivery"
assert_contains "points the migrate job at the released image" "${calls}" \
  "run jobs update api-migrate --image=us-central1-docker.pkg.dev/proj/finance/backend@sha256:abc"
# The two jobs #98 left behind. `purge-audit` runs monthly on a schedule and
# `seed-portfolios` by hand, so nothing in this run ever executes them — which
# is precisely why nothing was keeping their image current either.
assert_contains "points the purge-audit job at the released image" "${calls}" \
  "run jobs update api-purge-audit --image=us-central1-docker.pkg.dev/proj/finance/backend@sha256:abc"
assert_contains "points the seed job at the released image" "${calls}" \
  "run jobs update api-seed-portfolios --image=us-central1-docker.pkg.dev/proj/finance/backend@sha256:abc"
assert_not_contains "still never executes the purge job" "${calls}" "jobs execute api-purge-audit"
assert_not_contains "still never seeds on its own"       "${calls}" "jobs execute api-seed-portfolios"
assert_contains "runs the migrate job"       "${calls}" "run jobs execute api-migrate"
check "sets the job's image BEFORE running it" \
  "$(awk '/run jobs update api-migrate/{u=NR} /run jobs execute api-migrate/{e=NR} END{print (u && e && u < e) ? "ok" : "no"}' "${WORK}/calls.log")"
check "pins every job BEFORE the traffic shift" \
  "$(awk '/run jobs update api-seed-portfolios/{p=NR} /update-traffic/{t=NR} END{print (p && t && p < t) ? "ok" : "no"}' "${WORK}/calls.log")"
check "migrates BEFORE the traffic shift" \
  "$(awk '/run jobs execute api-migrate/{m=NR} /update-traffic/{t=NR} END{print (m && t && m < t) ? "ok" : "no"}' "${WORK}/calls.log")"
assert_contains "shifts traffic to the new revision"    "${calls}" "${SHIFT_NEW}"
assert_not_contains "never touches the old revision"    "${calls}" "${SHIFT_OLD}"
assert_contains "reports the deployed revision" "$(cat "${WORK}/out.txt")" "deployed api-00008-new"
assert_contains "summary names the revision"  "$(cat "${WORK}/summary.md")" "api-00008-new"

# ---------------------------------------------------------------- case 2
echo "case 2 · the revision never becomes Ready — no traffic moves forward (AC-4)"
make_stubs not_ready
assert_exit_nonzero "exits non-zero"
calls="$(cat "${WORK}/calls.log")"
assert_not_contains "new revision never got traffic"    "${calls}" "${SHIFT_NEW}"
assert_contains "traffic restored to the previous revision" "${calls}" "${SHIFT_OLD}"
assert_contains "summary records the rollback" "$(cat "${WORK}/summary.md")" "Rolled back"

# ---------------------------------------------------------------- case 3
echo "case 3 · the shifted revision reports another release — rolled back (AC-4, AC-5)"
make_stubs release_mismatch
assert_exit_nonzero "exits non-zero"
calls="$(cat "${WORK}/calls.log")"
assert_contains "new revision did take traffic first" "${calls}" "${SHIFT_NEW}"
assert_contains "then traffic went back"              "${calls}" "${SHIFT_OLD}"
assert_contains "the reason names the release found" "$(cat "${WORK}/out.txt")" "reports release '0.1.0+stale00'"

# ---------------------------------------------------------------- case 4
echo "case 4 · health never answers after the shift — rolled back (AC-4)"
make_stubs health_fail
assert_exit_nonzero "exits non-zero"
assert_contains "traffic went back" "$(cat "${WORK}/calls.log")" "${SHIFT_OLD}"

# ---------------------------------------------------------------- case 5
echo "case 5 · a release the expected one is only a PREFIX of is rejected (AC-5)"
make_stubs release_prefix
assert_exit_nonzero "exits non-zero"
assert_contains "traffic went back" "$(cat "${WORK}/calls.log")" "${SHIFT_OLD}"
assert_contains "the comparison is exact, not a substring match" \
  "$(cat "${WORK}/out.txt")" "reports release '0.1.0+a1b2c3d-dirty'"

# ---------------------------------------------------------------- case 6
echo "case 6 · the deploy itself fails — traffic is never touched at all (AC-4)"
make_stubs deploy_fails
assert_exit_nonzero "exits non-zero"
calls="$(cat "${WORK}/calls.log")"
assert_not_contains "no traffic call whatsoever" "${calls}" "update-traffic"
assert_contains "summary says the old revision still serves" \
  "$(cat "${WORK}/summary.md")" "api-00007-old"

# ---------------------------------------------------------------- case 7
echo "case 7 · an unresolvable revision is a hard failure, not a fallback (AC-4)"
make_stubs no_revision
assert_exit_nonzero "exits non-zero"
calls="$(cat "${WORK}/calls.log")"
assert_not_contains "nothing new took traffic" "${calls}" "${SHIFT_NEW}"
assert_contains "traffic restored to the previous revision" "${calls}" "${SHIFT_OLD}"
assert_contains "the reason is reported" "$(cat "${WORK}/out.txt")" "could not determine the created revision"

# ---------------------------------------------------------------- case 8
echo "case 8 · an explicit rollback moves traffic and deploys nothing"
make_stubs happy
CALL_LOG="${WORK}/calls.log"; : > "${CALL_LOG}"; : > "${WORK}/summary.md"; export CALL_LOG
if PATH="${WORK}/bin:${PATH}" SERVICE=api REGION=us-central1 PROJECT=proj \
   ROLLBACK_TO=api-00006-known-good GITHUB_STEP_SUMMARY="${WORK}/summary.md" \
   bash "${SCRIPT}" > "${WORK}/out.txt" 2>&1; then check "exits 0" ok; else check "exits 0" no; fi
calls="$(cat "${WORK}/calls.log")"
assert_contains "moves traffic to the named revision" "${calls}" "--to-revisions=api-00006-known-good=100"
assert_not_contains "deploys nothing" "${calls}" "run deploy"

# ---------------------------------------------------------------- case 9
echo "case 9 · missing required variables fail fast"
make_stubs happy
if PATH="${WORK}/bin:${PATH}" SERVICE=api REGION=us-central1 \
   bash "${SCRIPT}" > "${WORK}/out.txt" 2>&1; then check "exits non-zero" no; else check "exits non-zero" ok; fi
assert_contains "names the missing project" "$(cat "${WORK}/out.txt")" "PROJECT"

if PATH="${WORK}/bin:${PATH}" SERVICE=api REGION=us-central1 PROJECT=proj \
   IMAGE=img RELEASE=rel \
   bash "${SCRIPT}" > "${WORK}/out.txt" 2>&1; then check "exits non-zero without PUBLIC_URL" no; else check "exits non-zero without PUBLIC_URL" ok; fi
assert_contains "names the missing public url" "$(cat "${WORK}/out.txt")" "PUBLIC_URL"

# --------------------------------------------------------------- case 10
# The defect this closes (spec infra/0003, widened by infra/0004): a job kept
# the image it was created with, so it ran OLD code against a schema a newer
# revision had already moved. Both halves are asserted — the update happens,
# and a failure to set it is a hard stop with traffic untouched.
echo "case 10 · a job cannot be pointed at the released image"
make_stubs job_update_fails
assert_exit_nonzero "exits non-zero"
calls="$(cat "${WORK}/calls.log")"
assert_not_contains "never runs the job on an unknown image" "${calls}" "run jobs execute"
assert_not_contains "nothing took traffic" "${calls}" "${SHIFT_NEW}"
assert_contains "traffic restored to the previous revision" "${calls}" "${SHIFT_OLD}"
assert_contains "the reason names the images, not the schema" "$(cat "${WORK}/out.txt")" \
  "could not point every Cloud Run job at the released image"

# --------------------------------------------------------------- case 11
echo "case 11 · the migration itself fails: the schema was not moved, so nothing serves"
make_stubs migrate_fails
assert_exit_nonzero "exits non-zero"
calls="$(cat "${WORK}/calls.log")"
assert_contains "the job was attempted on the released image" "${calls}" \
  "run jobs update api-migrate --image=us-central1-docker.pkg.dev/proj/finance/backend@sha256:abc"
assert_not_contains "the new revision never took traffic" "${calls}" "${SHIFT_NEW}"
assert_contains "traffic restored to the previous revision" "${calls}" "${SHIFT_OLD}"
assert_contains "summary records the rollback" "$(cat "${WORK}/summary.md")" "Rolled back"

# --------------------------------------------------------------- case 12
# Anti-vacuity, and the reason this check is not a count of `jobs update`
# calls. `gcloud run jobs list --filter=…image-owner=delivery` answers with a
# WARNING and exit 0 when nothing carries the label — measured against the
# live project on 2026-09-22, before the label was applied. A deploy that read
# that as "no jobs to pin" would be green while pinning nothing, which is the
# defect of spec infra/0004 wearing the fix's clothes.
echo "case 12 · nothing carries the label: the deploy fails and says how to fix it"
make_stubs no_delivery_jobs
assert_exit_nonzero "exits non-zero"
calls="$(cat "${WORK}/calls.log")"
assert_not_contains "no job was updated"   "${calls}" "run jobs update"
assert_not_contains "no job was executed"  "${calls}" "run jobs execute"
assert_not_contains "nothing took traffic" "${calls}" "${SHIFT_NEW}"
assert_contains "traffic restored to the previous revision" "${calls}" "${SHIFT_OLD}"
out="$(cat "${WORK}/out.txt")"
assert_contains "the reason names the label"  "${out}" "image-owner=delivery"
assert_contains "and names the command that fixes it" "${out}" "terraform apply"

# --------------------------------------------------------------- case 13
# A non-empty list is not a correct list. If the migration — the one job this
# script also executes — is missing from it, the filter is answering about
# something else and the run must stop rather than migrate blind.
echo "case 13 · a list without the migrate job is a wrong list, not a short one"
make_stubs jobs_without_migrate
assert_exit_nonzero "exits non-zero"
calls="$(cat "${WORK}/calls.log")"
assert_not_contains "no job was updated"   "${calls}" "run jobs update"
assert_not_contains "no migration was run" "${calls}" "run jobs execute"
assert_not_contains "nothing took traffic" "${calls}" "${SHIFT_NEW}"
assert_contains "the reason names the missing job" "$(cat "${WORK}/out.txt")" \
  "api-migrate is not in the delivery-owned job list"

# --------------------------------------------------------------- case 14
# The failure the FIRST REAL DEPLOY after spec infra/0004 hit, which this
# suite could not have: it stubs `gcloud`, so it never meets an IAM decision.
# The deployer held `run.developer` on the service and on `migrate` only, so
# `jobs list` was refused — and `2>/dev/null || true` turned that refusal into
# an empty list. The run then reported "no Cloud Run job carries
# image-owner=delivery" and told the operator to run `terraform apply`, which
# had already run. Terraform was not the problem; the grant was.
#
# An error that answers the wrong question sends the reader somewhere else,
# which is worse than no check at all. The two cases must read differently.
echo "case 14 · a denial is diagnosed as a denial, not as a missing label"
make_stubs jobs_list_denied
assert_exit_nonzero "exits non-zero"
calls="$(cat "${WORK}/calls.log")"
assert_not_contains "no job was updated"   "${calls}" "run jobs update"
assert_not_contains "no job was executed"  "${calls}" "run jobs execute"
assert_not_contains "nothing took traffic" "${calls}" "${SHIFT_NEW}"
assert_contains "traffic restored to the previous revision" "${calls}" "${SHIFT_OLD}"
out="$(cat "${WORK}/out.txt")"
assert_contains "it quotes what gcloud said"        "${out}" "PERMISSION_DENIED"
assert_contains "it names the permission needed"    "${out}" "run.jobs.list"
assert_contains "it points at the IAM file"         "${out}" "infra/delivery.tf"
assert_not_contains "it does NOT blame terraform"   "${out}" "terraform apply"

echo
echo "${PASSED} passed, ${FAILED} failed"
[[ "${FAILED}" -eq 0 ]]
