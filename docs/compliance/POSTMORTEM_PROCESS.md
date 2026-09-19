# Postmortem Process

| | |
|---|---|
| **Owner** | Security owner (TL backend) · **Version** 1.0 — 2026-09-19 · **Next review** 2027-09-19 |
| **Maps to** | SOC 2 CC7.4 · ISO/IEC 27001 A.5.27 |

## Trigger

Mandatory for every SEV-1 and SEV-2 incident, for any data-loss event
(even if recovered), and for any red gate that reached `main`. Optional but
encouraged for SEV-3 and for "near misses".

## Rules

- **Blameless.** We write about systems, gaps and decisions, never about people's competence. Names appear only as roles ("the IC").
- **Timely.** Draft within 5 business days of closure; review meeting within 10.
- **Actionable.** Every action item has an owner, a due date and a GitHub issue. Items that change a control also update the risk register and, if relevant, a policy in this folder.
- **Public inside the team.** Postmortems live in `docs/postmortems/YYYY-MM-DD-<slug>.md`; the folder is created with the first one.

## Template

```markdown
# YYYY-MM-DD — <title>            SEV-n · duration Xh Ym · IC: <role>

## Summary            (3 lines: what broke, impact, how it was fixed)
## Impact             (users/data affected, data classification, notification made? y/n + link)
## Timeline (UTC)     (detection → declaration → containment → recovery → closure; one line per event)
## Root cause         (5-whys or causal chain; distinguish trigger from underlying cause)
## What went well
## What went badly / where we were lucky
## Action items       | # | action | owner | due | issue | status |
## Evidence retained  (location, retention period)
## Risk register update (R-n scores changed / new risk added)
```

## Follow-through

Action items are reviewed in the next [management review](isms/MANAGEMENT_REVIEW.md)
and closed in the [nonconformity log](isms/NONCONFORMITY_LOG.md) if the incident
revealed a policy nonconformity. Recurring root causes across postmortems are
escalated to a risk-register entry.

## Log

| Date | Incident | SEV | Postmortem |
|---|---|---|---|
| — | none yet | | |
