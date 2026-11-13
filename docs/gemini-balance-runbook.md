# Runbook — a Gemini balance alert fired

The agent calls Google AI Studio on a **prepaid** balance. Three alerts watch
it ([`infra/gemini_spend.tf`](../infra/gemini_spend.tf), spec
[infra/0006](../specs/infra/0006-the-spend-alert-fires-before-the-credit-runs-out.md)):

| Alert | Severity | Means |
|---|---|---|
| *Gemini estimated spend over 50 % of the credit in 24h* | WARNING | at this rate the balance lasts about a day more |
| *Gemini estimated spend over 80 % of the credit in 24h* | CRITICAL | the balance can run out within hours |
| *Gemini credit exhausted (HTTP 402)* | CRITICAL | it **has** run out: every agent turn now fails, the assistant answers nothing |
| *Gemini turn billed on an unpriced model* | WARNING | `GEMINI_MODEL` has no price in the table: those turns are **missing from the two spend alerts** |

**The 50 % / 80 % alerts are a burn rate, not a balance.** They compare the
estimated spend of the **last 24 h** with `gemini_credit_usd` — a number in
the environment's `*.tfvars`, not anything read from AI Studio. They do not
know what is left: a balance drained slowly over a week never fires them, and
a fresh top-up does not reset them. **Bump `gemini_credit_usd` on every
top-up** (§2), or the thresholds keep measuring the old credit. Only the 402
alert says the balance is actually gone.

The spend figures are an **estimate** from Gemini's `usageMetadata` and the
price table in `backend/src/app/core/model_pricing.py` (spec
[backend/0058](../specs/backend/0058-the-turn-reports-what-it-cost.md)). AI
Studio is the truth; the estimate only tells you when to look.

## 1. Check what was actually spent

1. Open [Google AI Studio](https://aistudio.google.com) with the account that
   owns the project's API key → **Usage & billing**.
2. Compare the console's spend with the estimate. In Logs Explorer:

   ```text
   resource.type="cloud_run_revision"
   jsonPayload.event="agent.turn"
   jsonPayload.model_calls_billed>0
   ```

   Each line carries `tokens_input`, `tokens_cached`, `tokens_output`,
   `tokens_thinking`, `model_calls_billed` and `estimated_cost_usd`.
3. If the two disagree by more than a few percent, the price table is stale:
   update `PRICES` and `PRICE_TABLE_VERSION` in `model_pricing.py` from the
   pricing page, in a PR.
4. If lines carry `price_missing=true` (the *unpriced model* alert),
   `GEMINI_MODEL` names a model the table does not know — those turns are
   **not** in the spend alerts' sum. Add the model's prices to `PRICES` from the
   pricing page, in a PR.

## 2. Top up

1. AI Studio → **Billing** → add prepaid credit.
2. **Every time:** set `gemini_credit_usd` in the environment's `*.tfvars` to
   the new credit and apply. The 50 %/80 % thresholds are fractions of that
   variable, never of the real balance.

## 3. Stop it happening again — auto-reload with a cap

1. AI Studio → **Billing** → enable **auto-reload** when the balance drops
   below a floor.
2. Set a **monthly cap** on auto-reload. The cap is the real spending limit;
   without it auto-reload converts an outage into an unbounded bill.
3. Record the floor and the cap in the ticket.

## 4. After the first apply (once per environment)

- Run one priced turn, then in **Metrics Explorer** → PromQL run
  `sum(increase(logging_googleapis_com:user_<metric_name_with_underscores>_sum[1h]))`
  and confirm it shows the turn's `estimated_cost_usd` (spec infra/0006 OD-1).
- **Slack** (spec infra/0007; the token never touches git or Terraform state):
  1. A workspace admin installs the *Google Cloud Monitoring* app in Slack and,
     in the target channel (`#finance-google-a2ui-dev`), runs
     `/invite @Google Cloud Monitoring`.
  2. Cloud Monitoring → *Alerting* → *Edit notification channels* → *Slack* →
     *Add new*, authorise the workspace, pick the channel, name it
     `finance-a2ui-dev Gemini spend (Slack)`.
  3. Read its id: `gcloud alpha monitoring channels list --project finance-a2ui
     --filter='type=slack' --format='value(name)'` (or the REST
     `notificationChannels` list).
  4. Put it in the environment's tfvars (not committed if it holds anything
     private; the id itself is not a secret):
     `spend_alert_channel_ids = ["projects/finance-a2ui/notificationChannels/<id>"]`
     and apply. The four policies now notify it.
  5. Prove it: *Edit notification channels* → the channel → *Send test
     notification*, and see it land in Slack.
- With `spend_alert_emails = []` the policies notify nobody: add at least one
  address or `spend_alert_channel_ids` before relying on them.

## 5. While the balance is zero

The client sees the usual *dependency unavailable* problem — whether our
account has money is never told to a caller (spec backend/0058 OD-4). Turns
log `outcome="model-out-of-credit"`; the service itself is healthy, so there
is nothing to roll back or restart. Top up (§2) and the next turn works.
