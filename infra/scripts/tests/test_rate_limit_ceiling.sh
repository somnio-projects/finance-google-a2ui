#!/usr/bin/env bash
# Guards that the rate limit the documentation promises is the one the
# infrastructure can actually deliver (GGU-83).
#
# `api/middleware/rate_limit.py` counts hits in PROCESS MEMORY. There is one
# counter per instance, so the effective per-principal budget is
#
#     effective limit = configured limit x max_instances
#
# which equals the documented limit only while `max_instances` is 1. That was
# true by decree (ADR-F D-4) and stopped being true when dev was scaled to 2 for
# the cold-start budget — a change made on cost grounds, against a constraint
# that lived in a different document, so nothing went red. The per-principal
# limit was silently twice what backend/docs/SECURITY.md documents, which is a
# SOC 2 CC6.6 control describing behaviour the system did not have.
#
# The fix taken (GGU-83, Option B) pins the instance count. That does NOT make
# the limiter correct — it makes the configuration match the limiter's real
# capability. The moment anyone raises the value the defect returns, which is
# why the Terraform line is not the deliverable and THIS FILE is: it is the
# thing that survives the decision being reversed.
#
# Three declarations, in three languages no single tool reads together:
#
#   1. HCL      infra/main.tf + infra/environments/*.tfvars  — the instance count
#   2. Python   backend/src/app/core/config.py + env.example — the configured limit
#   3. Markdown backend/docs/SECURITY.md                     — the documented limit
#
# `terraform validate` cannot see Python or Markdown, and `make gate` cannot see
# Terraform. This is the seam, so the assertion lives here, beside
# test_dev_environment.sh, which exists for exactly the same reason.
#
# Every value is PARSED rather than grepped for, and an unparseable declaration
# is a hard FAILURE, never an empty string that trivially agrees with another
# empty string: a check that quietly matches nothing is worse than no check, and
# a renamed heading in SECURITY.md must break the build rather than pass it
# vacuously. Same guard idiom as test_rules_index.sh.
set -Eeuo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA="$(cd "${HERE}/../.." && pwd)"
ROOT="$(cd "${INFRA}/.." && pwd)"

MAIN_TF="infra/main.tf"
SECURITY="backend/docs/SECURITY.md"
CONFIG="backend/src/app/core/config.py"
ENV_EXAMPLE="backend/env.example"
DIAGRAM="docs/diagrams/08-infrastructure.md"

# The command that fixes a red run. Identical to the `infra.rate-limit-ceiling`
# entry in .claude/ship-gate.json, the pre-commit hook and the infra-ci step
# (.claude/rules/ci-conventions.md §5 — copied, never paraphrased).
FIX="bash infra/scripts/tests/test_rate_limit_ceiling.sh"

PASSED=0
FAILED=0

pass() {
  echo "  PASS  $1"
  PASSED=$(( PASSED + 1 ))
}

fail() {
  echo "  FAIL  $1"
  FAILED=$(( FAILED + 1 ))
}

# Extracts the one capture group of ${2} from ${1}, or prints nothing. Callers
# must treat "nothing" as a failure — see the guards below.
capture() {
  local file="$1" expr="$2"
  sed -nE "${expr}" "${ROOT}/${file}" | head -1
}

# Reports a declaration that could not be read, naming the file and what was
# looked for, so a renamed heading is fixed rather than guessed at.
unreadable() {
  local what="$1" file="$2" looked_for="$3"
  fail "could not read ${what} from ${file}"
  echo "        looked for: ${looked_for}" >&2
  echo "        the comparison cannot run until it parses; fix the file or this script:" >&2
  echo "          ${FIX}" >&2
}

echo "every declaration is readable"

# --------------------------------------------------------------- the ceiling
# The derived default in main.tf. A bare integer rather than a ternary IS the
# assertion, exactly as it is for min_instances in test_dev_environment.sh: a
# ternary here would mean someone reintroduced a per-environment ceiling.
TF_CEILING="$(capture "${MAIN_TF}" \
  's/^  max_instances = coalesce\(var\.max_instances, ([0-9]+)\)$/\1/p')"
if [[ -z "${TF_CEILING}" ]]; then
  unreadable "the derived instance ceiling" "${MAIN_TF}" \
    "  max_instances = coalesce(var.max_instances, <n>)"
else
  pass "${MAIN_TF} derives max_instances = ${TF_CEILING}"
fi

# ------------------------------------------------------- the documented pair
# Two numbers, declared in prose the compliance reader actually reads, in a
# form this script can parse. Both must be present.
DOC_LIMIT="$(capture "${SECURITY}" \
  's/^- \*\*Documented per-principal limit:\*\* ([0-9]+) requests per minute\.$/\1/p')"
DOC_CEILING="$(capture "${SECURITY}" \
  's/^- \*\*Instance ceiling the limit depends on:\*\* ([0-9]+)\.$/\1/p')"
if [[ -z "${DOC_LIMIT}" ]]; then
  unreadable "the documented per-principal limit" "${SECURITY}" \
    "- **Documented per-principal limit:** <n> requests per minute."
else
  pass "${SECURITY} documents ${DOC_LIMIT} requests per principal per minute"
fi
if [[ -z "${DOC_CEILING}" ]]; then
  unreadable "the documented instance ceiling" "${SECURITY}" \
    "- **Instance ceiling the limit depends on:** <n>."
else
  pass "${SECURITY} documents an instance ceiling of ${DOC_CEILING}"
fi

# ------------------------------------------------------- the configured limit
CFG_LIMIT="$(capture "${CONFIG}" \
  's/^    rate_limit_per_minute: int = Field\(default=([0-9]+).*$/\1/p')"
if [[ -z "${CFG_LIMIT}" ]]; then
  unreadable "the configured limit" "${CONFIG}" \
    "    rate_limit_per_minute: int = Field(default=<n>, ...)"
else
  pass "${CONFIG} defaults rate_limit_per_minute to ${CFG_LIMIT}"
fi

ENV_LIMIT="$(capture "${ENV_EXAMPLE}" 's/^RATE_LIMIT_PER_MINUTE=([0-9]+)$/\1/p')"
if [[ -z "${ENV_LIMIT}" ]]; then
  unreadable "the sample limit" "${ENV_EXAMPLE}" "RATE_LIMIT_PER_MINUTE=<n>"
else
  pass "${ENV_EXAMPLE} ships RATE_LIMIT_PER_MINUTE=${ENV_LIMIT}"
fi

echo
echo "the documented limit is the limit the system enforces"

if [[ -n "${DOC_LIMIT}" && -n "${CFG_LIMIT}" ]]; then
  if [[ "${DOC_LIMIT}" == "${CFG_LIMIT}" ]]; then
    pass "the documented limit matches the configured default (${DOC_LIMIT}/min)"
  else
    fail "the documented limit and the configured default disagree"
    echo "          ${SECURITY} documents ......... ${DOC_LIMIT} requests per minute" >&2
    echo "          ${CONFIG} defaults to ......... ${CFG_LIMIT}" >&2
    echo "        change both or neither, then re-run:" >&2
    echo "          ${FIX}" >&2
  fi
fi

if [[ -n "${CFG_LIMIT}" && -n "${ENV_LIMIT}" ]]; then
  if [[ "${CFG_LIMIT}" == "${ENV_LIMIT}" ]]; then
    pass "the sample environment ships the configured default (${ENV_LIMIT}/min)"
  else
    fail "${ENV_EXAMPLE} ships ${ENV_LIMIT} while ${CONFIG} defaults to ${CFG_LIMIT}"
    echo "        a clone that copies env.example gets a limit nobody documented:" >&2
    echo "          ${FIX}" >&2
  fi
fi

echo
echo "the instance ceiling is the one the documented limit depends on"

# THE assertion. The limiter's budget is per process, so the documented limit is
# only true while exactly one process serves the traffic. Every declaration of
# the instance count is compared against the number SECURITY.md relies on.
if [[ -n "${TF_CEILING}" && -n "${DOC_CEILING}" ]]; then
  if [[ "${TF_CEILING}" == "${DOC_CEILING}" ]]; then
    pass "${MAIN_TF} and ${SECURITY} agree on ${TF_CEILING} instance(s)"
  else
    fail "the Terraform instance ceiling and the documented limit disagree"
    echo "          ${MAIN_TF} derives max_instances = ${TF_CEILING}" >&2
    echo "          ${SECURITY} documents an instance ceiling of ${DOC_CEILING}" >&2
    echo "          with a per-process limiter the effective budget becomes" >&2
    echo "          ${DOC_LIMIT:-?} x ${TF_CEILING} = $(( ${DOC_LIMIT:-0} * TF_CEILING ))" \
      "requests per principal per minute" >&2
    echo "        either restore the ceiling, or give the limiter a shared" >&2
    echo "        backing store and re-document it (spec backend/0001 OD-2,"  >&2
    echo "        ADR-F D-9). Then re-run:" >&2
    echo "          ${FIX}" >&2
  fi
fi

# A per-process limiter is only bounded at one process. If anything ever derives
# a higher ceiling, the document above is describing a control that is not there.
if [[ -n "${DOC_CEILING}" ]]; then
  if [[ "${DOC_CEILING}" -eq 1 ]]; then
    pass "the documented ceiling is 1, which is what a per-process counter needs"
  else
    fail "a ceiling of ${DOC_CEILING} needs a shared counter, and there is none"
    echo "        backend/src/app/api/middleware/rate_limit.py counts in memory;" >&2
    echo "        replace it before documenting a ceiling above 1 (GGU-83):" >&2
    echo "          ${FIX}" >&2
  fi
fi

# Every environment file that sets the knob by hand. `infra/environments` is the
# other place the count is declared, and main.tf's default cannot see it.
#
# Counted so the loop can never be vacuously green: a renamed directory or an
# extension change would otherwise silently assert nothing.
TFVARS_SEEN=0
while IFS= read -r tfvars; do
  rel="${tfvars#"${ROOT}"/}"
  # A trailing `# comment` is allowed — `terraform fmt` keeps the assignment
  # block aligned only when nothing sits between its lines.
  value="$(sed -nE 's/^max_instances *= *([0-9]+) *(#.*)?$/\1/p' "${tfvars}" | head -1)"
  [[ -z "${value}" ]] && continue
  TFVARS_SEEN=$(( TFVARS_SEEN + 1 ))
  if [[ -n "${DOC_CEILING}" && "${value}" == "${DOC_CEILING}" ]]; then
    pass "${rel} sets max_instances = ${value}"
  else
    fail "${rel} sets max_instances = ${value}, not the documented ${DOC_CEILING:-?}"
    echo "        this environment would enforce ${DOC_LIMIT:-?} x ${value} per principal:" >&2
    echo "          ${FIX}" >&2
  fi
done < <(find "${INFRA}/environments" -type f -name '*.tfvars' | sort)

if [[ "${TFVARS_SEEN}" -eq 0 ]]; then
  pass "no environment file hand-sets max_instances; all derive it"
fi

echo
echo "the diagram does not advertise a ceiling the limiter cannot hold"

# docs/diagrams/08-infrastructure.md draws the runtime, and .claude/rules/
# diagrams.md requires it to change in the same PR as the Terraform it
# describes. A range in that node is a claim about the instance count.
if ! grep -q 'backend service' "${ROOT}/${DIAGRAM}"; then
  unreadable "the Cloud Run service node" "${DIAGRAM}" "a node labelled 'backend service'"
elif grep -Eq 'backend service[^"]*[0-9]+[-–][0-9]+ instances' "${ROOT}/${DIAGRAM}"; then
  fail "${DIAGRAM} draws an instance range, but the ceiling is pinned to ${DOC_CEILING:-?}"
  grep -En 'backend service[^"]*instances' "${ROOT}/${DIAGRAM}" >&2
  echo "        redraw the node with the pinned count, then re-run:" >&2
  echo "          ${FIX}" >&2
else
  pass "${DIAGRAM} draws no instance range that could contradict the pin"
fi

echo
echo "${PASSED} passed, ${FAILED} failed"
[[ "${FAILED}" -eq 0 ]]
