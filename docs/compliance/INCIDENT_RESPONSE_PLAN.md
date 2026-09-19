# Incident Response Plan

| | |
|---|---|
| **Owner** | Security owner (TL backend) |
| **Approved by** | Engineering management |
| **Version** | 1.0 — 2026-09-19 · **Next review** 2027-09-19 or after every SEV-1/SEV-2 |
| **Maps to** | SOC 2 CC7.3, CC7.4, CC7.5 · ISO/IEC 27001 A.5.24, A.5.25, A.5.26, A.5.28 |

## 1. Severity levels

| SEV | Definition | Examples | Response start | Status updates |
|---|---|---|---|---|
| **SEV-1** | Confirmed or likely exposure of Confidential/Restricted data, or the service fully unavailable | leaked `AUTH_JWT_SECRET`/model key, unauthenticated access to `/v1/*`, database lost | immediately, 24×7 | every 60 min |
| **SEV-2** | Security control failed without confirmed data exposure, or major functionality down | rate limiter bypass, auth error mis-mapped to 200, migrations failing on deploy, Sentry flood of 500s | within 1 business hour | every 4 h |
| **SEV-3** | Degradation, suspicious activity, vulnerability with no evidence of exploitation | CRITICAL CVE in a dependency, unusual 401 spike, flag toggled by an unknown admin subject | within 1 business day | daily |
| **SEV-4** | Low-risk finding, policy nonconformity | expired exception, missing audit event on a new route | next sprint | at closure |

## 2. Roles

| Role | Default | Backup | Duties |
|---|---|---|---|
| Incident commander (IC) | Security owner (TL backend, `@lautarob`) | Backend engineer (`@mcampbell-somnio`) | declares severity, owns the timeline, decides containment, calls the postmortem |
| Technical lead | Backend engineer on the affected area | IC | investigates, implements containment/fix |
| Communications | PM / integrator (`@pburzaco-somnio`) | Eng. management | internal updates, stakeholder (Google reviewer) notice, breach notification per [BREACH_NOTIFICATION_SLA.md](BREACH_NOTIFICATION_SLA.md) |
| Scribe | anyone not in the above | — | keeps the incident channel timeline |

Contact path: Slack `#finance-google-a2ui-dev` → direct Slack call → phone
(numbers in Somnio's people portal). Sentry alerts route to the same channel
(CLOUD_SERVICES §5).

## 3. Lifecycle

1. **Detect** — Sentry alert, `/readyz` failing, CI/scheduled-scan issue, report to `security@somniosoftware.com`, audit-trail anomaly (`audit_events` query by action/subject), or a teammate's observation.
2. **Declare** — IC posts `INCIDENT SEV-n: <one line>` in the channel, opens a thread, assigns roles. A GitHub issue labelled `incident` is opened for SEV-1/2.
3. **Contain** — pick the runbook in §4. Preserve evidence first (§5) unless containment cannot wait.
4. **Eradicate & recover** — fix through the normal PR path or [EMERGENCY_CHANGE.md](EMERGENCY_CHANGE.md) for SEV-1/2; verify with `make gate`, health probes and the audit trail; restore data per [DISASTER_RECOVERY_PLAN.md](DISASTER_RECOVERY_PLAN.md) if needed.
5. **Notify** — communications lead follows the SLA document; IC decides whether the event is a *breach* (unauthorised access to Confidential/Restricted data) using the checklist in that document.
6. **Close** — IC posts the closure note; postmortem scheduled within 5 business days ([POSTMORTEM_PROCESS.md](POSTMORTEM_PROCESS.md)).

## 4. Containment runbooks (top failure modes)

| Scenario | Containment | Then |
|---|---|---|
| **Leaked signing secret / model key** | Rotate the secret in Secret Manager and redeploy (all HS256 tokens become invalid — intended); revoke the leaked key at the provider; set `FEATURE_FLAGS_FORCE_DISABLED` for affected routes if rotation must wait | search git history and CI logs for the leak path; add a gitleaks rule if a pattern was missed |
| **Misbehaving or exploited endpoint** | `PUT /v1/admin/feature-flags/<key> {"enabled": false}` (audited) or `FEATURE_FLAGS_FORCE_DISABLED=<key>` + restart — the route answers 404 within the cache TTL (15 s) | fix behind the flag, re-enable after `make gate` |
| **Abusive client / DoS** | Lower `RATE_LIMIT_PER_MINUTE`, tighten `CORS_ALLOWED_ORIGINS` / `TRUSTED_HOSTS`, block at Cloud Armor (prod) | analyse `request_id`-correlated logs; postmortem if capacity was the cause |
| **Compromised user or admin subject** | Revoke at the identity provider (OIDC) — the API is stateless; for HS256 service tokens rotate the secret; audit `audit_events where subject = …` | notify per SLA if Confidential data was read |
| **Bad migration / data corruption** | Stop writes (scale to 0 or disable routes), take a fresh dump, restore per DR plan, `alembic downgrade` only if the revision is reversible | add the missing migration test; postmortem |
| **Dependency CVE with exploit in the wild** | Dependabot/`uv lock --upgrade-package`, `make gate`, deploy; if no fix exists, mitigate (WAF rule, disable route) | track under [PATCH_POLICY.md](PATCH_POLICY.md) |
| **Unhandled 500 storm** | Sentry issue → identify route → disable via flag; roll back the last deploy if it correlates | fix, add the regression test |

## 5. Evidence collection and preservation (A.5.28)

- Do **not** restart or wipe the affected container before capturing `docker logs` / Cloud Logging export and a `pg_dump` snapshot; store them in a restricted bucket/folder named `incident-<date>-<id>`, access limited to IC + technical lead.
- Correlate by `request_id` (response header `X-Request-ID`, structlog field, `audit_events.request_id`). Logs never contain tokens or PII by design; do not add them during the incident.
- Keep evidence for 12 months after closure (longer if legal asks); record the retention decision in the postmortem.
- Chain of custody: who exported what, when, where it lives — in the incident issue.

## 6. Communication rules

- One channel thread is the source of truth; the scribe pins the timeline.
- External statements (Google, reporters, public) only through communications lead after IC + management approval.
- Never share secrets, tokens, or raw logs in Slack; share file locations.

## 7. Testing this plan

A tabletop exercise (leaked-secret scenario) runs once a year and after any
change to the roles table; the outcome is recorded in
[isms/INTERNAL_AUDIT_PROGRAM.md](isms/INTERNAL_AUDIT_PROGRAM.md). First
exercise: scheduled for 2026-Q4 (owner: security owner).
