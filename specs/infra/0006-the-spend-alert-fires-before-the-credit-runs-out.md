# 0006 — The spend alert fires before the Gemini credit runs out

- **Area:** infra
- **Status:** In progress — validated, not applied
- **Ticket:** [GGU-167](https://somniosoftware.atlassian.net/browse/GGU-167) (the prepaid balance ran out during a QA spike, 2026-11-13)
- **Also:** [backend/0058](../backend/0058-the-turn-reports-what-it-cost.md) (the `agent.turn` fields this reads), runbook [`docs/gemini-balance-runbook.md`](../../docs/gemini-balance-runbook.md), diagram [08](../../docs/diagrams/08-infrastructure.md)
- **Owner:** Lautaro Bertuzzi · **Date:** 2026-11-13

## 1. Problem

The agent runs on a **prepaid** Google AI Studio balance (US$5). On
2026-11-13 it reached zero mid-QA; every model call then answered HTTP 402 and
the assistant stopped. Nobody was warned before, and nobody was paged after.
AI Studio exposes no balance API for a prepaid key, so the only number we own
is the estimate the backend now writes on every `agent.turn`
([backend/0058](../backend/0058-the-turn-reports-what-it-cost.md) §3).

## 2. Scope

**In** — `infra/gemini_spend.tf`, two variables in `infra/variables.tf`:

| Resource | What |
|---|---|
| `google_logging_metric.gemini_cost` | DELTA **distribution** of `EXTRACT(jsonPayload.estimated_cost_usd)` over `agent.turn` lines with `model_calls_billed>0` and `price_missing=false` |
| `google_monitoring_alert_policy.gemini_spend["50"]` / `["80"]` | PromQL: rolling 24 h `sum(increase(<metric>_sum[24h]))` above 50 % (WARNING) / 80 % (CRITICAL) of `var.gemini_credit_usd` |
| `google_monitoring_alert_policy.gemini_out_of_credit` | log-match on any `agent.turn` with `outcome="model-out-of-credit"` (CRITICAL), at most one notification per hour |
| `google_monitoring_notification_channel.spend_email` | one email channel per entry of `var.spend_alert_emails` |

| Variable | Default | Meaning |
|---|---|---|
| `gemini_credit_usd` | `5` | the balance the thresholds are fractions of; update it on top-up |
| `spend_alert_emails` | `[]` | recipients; **empty creates the policies with no channel** — they open incidents in Cloud Monitoring and notify nobody |

**Out:**

- **Slack.** A Slack notification channel needs an OAuth grant performed in
  the console by a workspace member; Terraform cannot complete it and this
  configuration does not pretend to. It is a human step in the runbook.
- **The real balance.** Not readable (backend/0058 OD-1).
- **Applying.** Validated (`terraform fmt`, `validate`, `trivy config`), not
  applied — applying is a human step, as for every file in `infra/`.

## 3. Why these shapes

- **Distribution, not counter.** A log-based counter counts entries; it cannot
  add up a field. A distribution keeps the sum of what it extracts, which
  PromQL exposes as `<metric>_sum`, so a 24 h sum is one `increase()`.
- **PromQL, not a threshold condition.** A `condition_threshold` on a
  distribution can only compare a percentile or a mean, never the sum. MQL is
  deprecated; PromQL is the supported way to ask for it.
- **Log-match for 402.** The credit being gone is a single event that needs a
  human now; waiting for a metric alignment period would only delay the page.
- **Filtered, not failed.** Turns that billed nothing (scripted client, direct
  calls) and turns with no price (`price_missing`) are excluded by the filter
  rather than left for `EXTRACT` to fail on.

## 4. Data model & migration

None.

## 5. Security notes

The metric and the policies read counts, a price and an outcome — no prompt,
reply or subject is on the line (backend/0058 §5). Email addresses are
variables, never committed in `*.tfvars` by this change.

## 6. Acceptance criteria

1. **AC-1** — `terraform fmt -check`, `terraform validate` and `trivy config`
   (HIGH/CRITICAL) pass over `infra/`.
2. **AC-2** — the metric extracts the exact field the backend writes, and the
   out-of-credit filter names the exact outcome it records: asserted by
   `backend/tests/unit/services/test_spend_alert_contract.py`, which
   `backend-ci` runs whenever `infra/gemini_spend.tf` changes.
3. **AC-3** — both thresholds are derived from `var.gemini_credit_usd`; no
   amount is hard-coded in a policy.
4. **AC-4** — with `spend_alert_emails = []` the plan creates the three
   policies and no channel.

## 7. Test plan

| AC | Check |
|---|---|
| AC-1 | `infra-ci` job *Terraform* (and the same commands locally) |
| AC-2 | `py.test` (`test_spend_alert_contract.py`) |
| AC-3, AC-4 | review of `gemini_spend.tf`; the first `terraform plan` |

## 8. Open decisions

| # | Question | Owner | Default if unresolved |
|---|---|---|---|
| OD-1 | Does `increase(..._sum[24h])` read a log-based DELTA distribution as expected? | Lautaro | Expected per the Cloud Monitoring PromQL mapping; **verify in Metrics Explorer after the first apply** with one priced turn (runbook §4). |
| OD-2 | Route to the existing on-call email too? | Lautaro | No — spend is an owner's decision (a card), not an on-call incident; recipients are their own list. |
| OD-3 | Alert per environment or project-wide? | Lautaro | Per environment, like every other policy here; dev and production may share one AI Studio key, in which case set the same `gemini_credit_usd` and expect the alerts to fire independently. |
