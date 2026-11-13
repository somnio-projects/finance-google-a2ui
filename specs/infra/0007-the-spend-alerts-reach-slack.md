# 0007 — The Gemini spend alerts reach Slack

- **Area:** infra
- **Status:** In progress — validated, not applied
- **Ticket:** [GGU-167](https://somniosoftware.atlassian.net/browse/GGU-167)
- **Also:** [infra/0006](0006-the-spend-alert-fires-before-the-credit-runs-out.md), runbook [`docs/gemini-balance-runbook.md`](../../docs/gemini-balance-runbook.md) §4, diagram [08](../../docs/diagrams/08-infrastructure.md)
- **Owner:** Lautaro Bertuzzi · **Date:** 2026-11-13

## 1. Problem

The four Gemini alert policies notify only `var.spend_alert_emails`. The
project/account manager asked (2026-11-13) for the alert in Slack, in the
team channel `#finance-google-a2ui-dev`, so it is seen where the team already
works.

## 2. Options

| | Mechanism | Secrets | Moving parts |
|---|---|---|---|
| (a) | `google_monitoring_notification_channel` type `slack` with `sensitive_labels.auth_token` | Slack OAuth token in git or in Terraform **state** | one resource, but the token must be minted by hand anyway |
| (b) | Pub/Sub channel + forwarder to an incoming webhook | webhook URL in Secret Manager | topic, function/job, IAM, code to maintain |
| (c) | Human authorises the *Google Cloud Monitoring* Slack app in the console; Terraform **references** the channel id | none: the token stays inside Google | one variable |

**Decision: (c).** Keeps every secret out of git and state, adds no runtime
code, and the wiring (which policies notify it) is still reviewed as code.
The cost is one human step, which (a) needs as well because the OAuth grant
cannot be performed by Terraform.

## 3. Scope

`infra/variables.tf`: new `spend_alert_channel_ids` (list of full channel
names, default `[]`, validated shape). `infra/gemini_spend.tf`:
`gemini_alert_channels` = email channels + those ids, so all four policies
notify them. Runbook §4, `infra/README.md`, diagram 08 updated.

**Out:** creating the Slack channel from Terraform (option a); applying.

## 4. Security notes

A channel id is not a secret. No token, webhook URL or Slack identifier is
committed. The grant is revocable in Slack (app removal) with no code change.

## 5. Acceptance criteria

1. **AC-1** — `terraform fmt -check`, `validate`, `trivy config` pass.
2. **AC-2** — with `spend_alert_channel_ids = []` the plan is unchanged from 0006 (AC-4 there).
3. **AC-3** — a malformed id fails validation with a message naming the expected shape.
4. **AC-4** — every id given appears in `notification_channels` of all four policies.
5. **AC-5** — after apply, *Send test notification* lands in the Slack channel.

## 6. Test plan

AC-1..4: the `infra.*` gate commands plus `terraform validate` with a bad and a good value; AC-5 manual after the human step, evidence in the PR/Jira.
