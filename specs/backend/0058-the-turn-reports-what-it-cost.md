# 0058 — The turn reports what it cost, and says when the credit is gone

- **Area:** backend
- **Status:** In progress
- **Ticket:** [GGU-167](https://somniosoftware.atlassian.net/browse/GGU-167) (the prepaid balance ran out during a QA spike, 2026-11-13)
- **Also:** [0006](0006-agent-host.md) (the agent host, AC-13: what `agent.turn` may carry), [0056](0056-the-drill-runs-its-tool-without-the-model.md) (the direct call — a turn with no model call), [infra/0006](../infra/0006-the-spend-alert-fires-before-the-credit-runs-out.md) (the metric and the alerts that read this line), runbook [`docs/gemini-balance-runbook.md`](../../docs/gemini-balance-runbook.md)
- **Owner:** Lautaro Bertuzzi · **Date:** 2026-11-13

## 1. Problem

The agent calls Google AI Studio (`generativelanguage.googleapis.com/v1beta`,
model `gemini-3.8-flash`) on a **prepaid** balance of US$5. During a QA spike
on 2026-11-13 the balance reached zero; from then on every `generateContent`
answered **HTTP 402** and the assistant stopped answering. Nothing warned
anyone first, and nothing afterwards said *why*:

| What we had | What it could not say |
|---|---|
| `agent.turn` — model, outcome, duration, iterations, tool calls, surfaces, views | how many tokens a turn spent, or what they cost |
| `infra/model/reply.py` — reads `candidates` | Gemini's `usageMetadata` was parsed by nobody |
| `outcome=model-unavailable` | a 402 (out of credit) and a 503 (provider down) produced the **same** outcome — one needs a top-up, the other needs patience |

Measured on 2026-11-13: an average turn makes **1.94** model calls (bound
`AGENT_MAX_TOOL_ITERATIONS=4`), each retried up to `GEMINI_MAX_ATTEMPTS=3`
times on transport/408/429/5xx. A turn's cost is therefore a sum over calls
**and** over attempts, and only Gemini knows the token counts.

## 2. Scope

**In:**

- Read `usageMetadata` on every attempt into a typed core value, thread it
  from the model client through the loop, and sum it per turn (AC-1 … AC-4).
- A declared, versioned, tested price table and a pure cost function
  (AC-5 … AC-7).
- Six new fields on `agent.turn`, plus a price-missing flag (AC-8, AC-9).
- HTTP 402 from Gemini as its own outcome, `model-out-of-credit`, with the
  client's problem unchanged (AC-10, AC-11).

**Out:**

- The log-based metric and the alert policies — [infra/0006](../infra/0006-the-spend-alert-fires-before-the-credit-runs-out.md).
- Reading the real balance. AI Studio exposes no balance API for a prepaid
  key; the estimate is the only number we own (OD-1).
- `generationConfig` / `thinkingConfig` (a thinking budget would cut cost; it
  changes answers and is a separate decision).
- Any per-user or per-session attribution of cost — the line stays per turn
  and carries no subject (§5).

## 3. Contract

No HTTP surface changes. The **log line** is the contract, read by
[infra/0006](../infra/0006-the-spend-alert-fires-before-the-credit-runs-out.md):

| field | type | meaning |
|---|---|---|
| `tokens_input` | int | `promptTokenCount` summed over every billed attempt of the turn (includes cached) |
| `tokens_cached` | int | `cachedContentTokenCount`, the part of `tokens_input` billed at the cached rate |
| `tokens_output` | int | `candidatesTokenCount` |
| `tokens_thinking` | int | `thoughtsTokenCount` — **billed as output** |
| `model_calls_billed` | int | attempts whose response carried `usageMetadata` (retries included) |
| `estimated_cost_usd` | JSON **number**, ≥ 0, 6 decimal places | the estimate under §3.1; `null` when the model has no price |
| `price_missing` | bool | true exactly when tokens were billed and the table has no price for the model |

`estimated_cost_usd` is a number, not a string, because it is what a Cloud
Logging distribution metric extracts with `EXTRACT(jsonPayload.estimated_cost_usd)`
(OD-2). It is computed in `Decimal` and converted only at the log boundary.

### 3.1 The price

`app/core/model_pricing.py` — `PRICE_TABLE_VERSION = "2026-11-13"`, read from
the Google AI Studio pricing page (Standard tier) that day:

| model | effective from | input / 1M | cached input / 1M | output (incl. thinking) / 1M |
|---|---|---|---|---|
| `gemini-3.8-flash` | (earliest) | $0.75 | $0.075 | $3.75 |
| `gemini-3.8-flash` | 2027-01-01 | $1.50 | $0.15 | $7.50 |

    cost = (input − cached) · in + cached · cachedIn + (output + thinking) · out

per million tokens. The band is chosen by the **turn's own date**, which comes
from the injected `Clock` (no clock read in pure code). The first band has no
start date because the table records when we read the price, not when Google
set it.

### 3.2 Errors

`app/core/model_errors.py`:

| class | parent | outcome | client sees |
|---|---|---|---|
| `ModelProviderError` | `DependencyUnavailableError` | `model-unavailable` | 503 `dependency-unavailable`, *"model provider unavailable"* |
| `ModelOutOfCreditError` | `ModelProviderError` | `model-out-of-credit` | **the same** 503 problem |

Both carry the `TokenUsage` the failed call still billed. The client's RFC 9457
problem does not change: whether our account has money is not something an
anonymous caller is told (§5).

## 4. Data model & migration

None.

## 5. Security notes

- The new fields are counts and a price. No prompt, reply, tool argument, tool
  result or subject reaches the line; the exact-key-set test of spec 0006
  AC-13 is extended rather than relaxed.
- A 402 stays masked outward (`dependency-unavailable`, fixed detail) and is
  recorded inward, as GGU-90 AC-4 already does for every provider status.
- `usageMetadata` is read from the **response** body; the API key is in a
  request header and never near it.

## 6. Acceptance criteria

1. **AC-1** — `usage_from(payload)` reads the five `usageMetadata` counts,
   each optional (absent = 0); a body with no `usageMetadata`, a non-object
   body or a malformed block yields zero usage and **never raises**.
2. **AC-2** — `GeminiModelClient.generate` returns a `ModelReply` whose
   `usage` is the sum over **every attempt** of the call, retries included; an
   attempt with no body (timeout, transport error) or no `usageMetadata`
   counts zero.
3. **AC-3** — a failed call raises `ModelProviderError` carrying the usage its
   attempts billed — including a 200 whose body carried usage but no candidate.
4. **AC-4** — the loop adds every call's usage, successful or failed, to
   `TurnState.usage`; a direct turn (spec 0056) reports zero usage and zero
   cost.
5. **AC-5** — `estimate_cost` implements §3.1 exactly in `Decimal`, choosing
   the band by the date it is handed.
6. **AC-6** — an unknown model with billed tokens yields `None`; zero billed
   calls yield `0` for **any** model (nothing billed costs nothing).
7. **AC-7** — the price table is well formed: every model's bands start with
   the open band and are strictly increasing in date; every price is
   non-negative; `cached ≤ input`.
8. **AC-8** — `agent.turn` carries the seven fields of §3 and nothing else
   new; the key set is asserted exactly.
9. **AC-9** — `estimated_cost_usd` is a JSON number rounded to 6 decimal
   places, or `null` with `price_missing=true`.
10. **AC-10** — a Gemini 402 raises `ModelOutOfCreditError`, is not retried,
    and the turn records `outcome=model-out-of-credit` (log line and metric
    tag).
11. **AC-11** — every other provider failure still records
    `model-unavailable`, and a database `DependencyUnavailableError` inside a
    tool still does too (unchanged).
12. **AC-12** — the field name and the outcome string the alerts read are the
    ones this code emits: a test compares `infra/gemini_spend.tf` against the
    Python constants, and `backend-ci` runs on a change to that file.

## 7. Test plan

| AC | Unit test(s) |
|---|---|
| AC-1 | `tests/unit/infra/model/test_usage.py` |
| AC-2, AC-3, AC-10 | `tests/unit/infra/model/test_gemini_usage.py` |
| AC-4 | `tests/unit/services/test_agent_usage.py` |
| AC-5 … AC-7 | `tests/unit/core/test_model_pricing.py` (and `test_model_usage.py` for the sum and the masked errors) |
| AC-8, AC-9 | `tests/unit/services/test_agent_telemetry.py`, `test_agent_usage.py` |
| AC-10, AC-11 | `tests/unit/services/test_agent_failures.py`, `test_agent_usage.py` |
| AC-12 | `tests/unit/services/test_spend_alert_contract.py` |

Integration: none — no route, table or query changes; the manual run in the PR
exercises the real `GeminiModelClient` against a recorded Gemini body.

Mutation checks: error masking — `ModelOutOfCreditError` keeps the 503 problem
(asserted on the class's `status`, `code` and detail).

## 8. Open decisions

| # | Question | Owner | Default if unresolved |
|---|---|---|---|
| OD-1 | Read the real balance instead of estimating? | Lautaro | No — AI Studio has no balance API for a prepaid key. The estimate leads; the console stays the truth (runbook). |
| OD-2 | Number or string for `estimated_cost_usd`? | Lautaro | Number: `EXTRACT` on a distribution metric needs a value convertible to double, and a number needs no parsing. |
| OD-3 | Count retried attempts? | Lautaro | Yes, when Gemini returned `usageMetadata` for them — they are billed. A 4xx/5xx without it counts zero. |
| OD-4 | Should the client be told the credit is gone? | Lautaro | No. Same 503 problem; the operator learns it from the log and the alert. |

## 9. Rollout & observability

No flag: the fields are additive and the outcome is new. Once deployed, the
first `agent.turn` with `model_calls_billed > 0` is the proof the live
`usageMetadata` is shaped as recorded here — until then the shape is from the
Gemini API reference and a recorded fixture, not from our own traffic.
