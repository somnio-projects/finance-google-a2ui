# Emergency Change Procedure

| | |
|---|---|
| **Owner** | TL backend · **Version** 1.0 — 2026-09-19 · **Next review** 2027-09-19 |
| **Maps to** | SOC 2 CC8.1 · ISO/IEC 27001 A.8.32 |

## When it applies

Only during a declared **SEV-1 or SEV-2** incident
([INCIDENT_RESPONSE_PLAN.md](INCIDENT_RESPONSE_PLAN.md)) when waiting for
the normal path would prolong exposure or downtime — e.g. rotating a leaked
secret, disabling an exploited route, rolling back a bad deploy.

## What may be bypassed — and what may not

| May be bypassed (temporarily) | Never bypassed |
|---|---|
| waiting for a second reviewer (IC approves alone) | gitleaks / secret scanning |
| the full spec/plan cycle | 100 % coverage on the **fix commit** that follows within 24 h |
| the CODEOWNERS review *before* deploy (done after) | audit trail: the change must be traceable to the incident issue |
| staging soak | the `.env`/secret handling rules |

Configuration-only mitigations (feature flag off, kill-switch env var, rate
limit lowered, secret rotated) need no code change and are the preferred
emergency action — they are audited or logged by design.

## Steps

1. IC states in the incident thread: `EMERGENCY CHANGE: <what> — approved by <IC>`; eng. management is informed (SEV-1: before; SEV-2: within 1 h).
2. Apply the mitigation (config) or push a branch `hotfix/<incident>-<slug>`; open the PR immediately, labelled `emergency`, referencing the incident issue.
3. Deploy from the branch/commit once **the gate is green**. If the gate cannot be green in time (e.g. CI outage), deploy anyway and say so in the PR — this is the only case where an unreviewed commit reaches production.
4. **Within 24 h**: a code owner reviews the PR post-hoc; missing tests/docs are added; the PR is merged to `main` (or reverted and redone properly).
5. **Within 5 business days**: postmortem; the emergency change is listed in the [nonconformity log](isms/NONCONFORMITY_LOG.md) with "post-hoc review completed: date".

## Authorised approvers

Incident commander (security owner or backup). Eng. management can veto.

## Log

| Date | Incident | Change | Deployed by | Post-hoc review | PR |
|---|---|---|---|---|---|
| — | none yet | | | | |
