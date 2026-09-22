# 0036 — The turn is fast, honest, and observable

- **Area:** backend (agent host, model adapter, prompt, telemetry)
- **Status:** In progress
- **Ticket:** _unassigned — no GGU number exists for this yet; none is invented here_
- **Also:** [frontend/0019](../frontend/0019-the-turn-always-ends.md) (the client half of the same failure), [backend/0006](0006-agent-host.md) (the turn), [backend/0011](0011-holdings-tool.md) OD-1 (when the chart fits), [backend/0033](0033-the-simulated-assistant-offline.md) (no key = scripted), [ADR-K](../../docs/adr/ADR-K-response-shaping.md) D-11/D-12/D-14
- **Owner:** Lautaro Bertuzzi · **Date:** 2026-09-22

## 1. Problem

The agent was reported as "crashing". Exercised against the real Gemini model
on a local stack and read off dev's logs, it was not crashing — it was doing
four separate things wrong, and **none of them was visible in telemetry**.

| Measured | Where |
|---|---|
| `agent.turn outcome=model-unavailable duration_ms=64416`, preceded by three `model_provider_unreachable error=ReadTimeout` | dev, 16:46 |
| The same questions answering in **10.3 / 27.9 / 37.6 / 38.2 / 45.8 s** | local, live model |
| *"Here is your portfolio allocation broken down by sector"* followed by a ` ```json ` block containing the render intent — **2 of 3 identical runs** | local, live model |
| The third run refusing: *"sector-level data is not available from my tools"* — for an option the catalog **declares** | local, live model |
| A donut of **14 slices by holding** under a sentence claiming sectors | the TL's screenshot |

The last one is the serious one: **the answer and the surface disagreed, and
the surface was right.**

## 2. Rulings

- **OD-1 — a read timeout is not a retry, and 20 s was below a normal turn.**
  `is_retryable` returned `True` for every `httpx.TransportError`, and
  `ReadTimeout` is one. A connection refused is a provider that failed; a read
  timeout is a provider that answered **too slowly**, and the retry asks the
  same slow model the same question with the same budget. Three attempts at
  20 s is how a 64 s `model-unavailable` was produced for a question that
  answers in 10–46 s. `GEMINI_TIMEOUT_SECONDS` defaults to **60**, and a
  `ReadTimeout` is not retried. `ConnectTimeout` stays retryable: never
  reaching the host genuinely is transient.

- **OD-2 — the prompt promised a capability the model does not have.**
  `PROMPT_HEADER` said *"Pick one by id and fill only the options listed for
  it"*. A surface is attached by the **tool** (`ToolOutcome.render`); there is
  no channel through which the model can name a view. Told to do something it
  cannot, it wrote the intent into its prose. The header now says the tool
  attaches the surface, that the model's lever is which tool it calls and with
  which arguments, and that it must never write a view id, an options object
  or JSON in an answer.

- **OD-3 — the option existed, and nothing passed it.**
  `holdings.allocation.v1` has declared `group_by: [holding, asset_class,
  sector]` all along; `chart_options` returned `{"top_n": N}` and nothing
  else, so every chart drew at its default. `get_holdings_summary` now takes
  a `group_by` argument and threads it into the intent. The grouping is
  **not** a reason to draw a chart that does not fit: a filtered or
  return-ordered answer still gets no chart (0011 OD-1), asserted.

  The vocabulary is declared twice — in the projection's options model and in
  the tool's schema — and neither generates the other, so
  `test_the_tool_offers_every_grouping_the_projection_declares` reads the
  projection's own JSON schema and compares. Two hand-written declarations of
  one contract is the drift this repository checks rather than trusts.

- **OD-4 — a turn that draws nothing logged the same as one that draws four.**
  `record_turn` carried `model`, `outcome`, `duration_ms`, `iterations` and
  `tool_calls`. Whether the turn **composed** anything — the entire point of
  this product — was absent, which is why the sector defect survived: no log
  line anywhere could have shown the disagreement. The line now carries
  `surfaces` (a count) and `views` (the ids), and the metric a `composed`
  tag. A view id is a catalog identifier, not a prompt, a reply, a tool
  argument or a subject, so spec 0006 §5's logging rule is untouched —
  `test_the_turn_log_line_carries_no_prompt_no_result_and_no_subject` names
  the new keys and still asserts all three absences.

  `composed` is a **tag** and the ids are **fields**, on purpose: a tag's
  value set becomes a time series, and "did this turn draw anything" is the
  question worth a series.

- **OD-5 — what is NOT fixed here.** There is no dividend-income tool. Asked
  *"what did I earn in dividends this year?"* the agent answers *"dividend
  income data is not available"* while the Activity tab shows dividends for
  VOO, MSFT, AAPL and JNJ. That is a real gap, it belongs with the seeding
  work (spec `backend/0035`), and it is named here rather than left for
  someone to rediscover.

## 3. Acceptance criteria

1. **AC-1** — `GEMINI_TIMEOUT_SECONDS` defaults to 60; `env.example` says why.
2. **AC-2** — `is_retryable` is `False` for `ReadTimeout` and `True` for `ConnectTimeout`.
3. **AC-3** — the prompt header states that tools attach surfaces and forbids writing a view id, an options object or JSON in an answer.
4. **AC-4** — `get_holdings_summary` accepts `group_by`, offers exactly the groupings the projection declares, and puts the chosen one in the render intent.
5. **AC-5** — a filtered or return-ordered call still produces no chart, whatever `group_by` says.
6. **AC-6** — `agent.turn` carries `surfaces` and `views`; the metric carries `composed`; no prompt, reply or subject appears in the line.
7. **AC-7** — `cd backend && make gate` green, 100 % branch coverage.

## 4. Test plan

| AC | How |
|---|---|
| 2 | `test_provider_errors.py`, parametrised, plus a test asserting `ReadTimeout` **is** a `TransportError` — the rule is a carve-out, not a restatement |
| 4 | `test_holdings_grouping.py` reads the projection's JSON schema and compares it with `GROUPINGS` and with the schema the model reads |
| 5 | same file — a filtered call and an empty call both return `None` |
| 6 | `test_agent_telemetry.py` — one test for a turn that composes, one for a turn that does not, and the existing no-PII test extended to the new keys |
| 1, 3, 4, 6 | **live model**, three runs of one question, before and after |

## 5. Verified against the live model

Local stack, real Gemini (`gemini-3.8-flash`), *"How is my portfolio split by
sector?"*, three runs each:

| | before | after |
|---|---|---|
| ` ```json ` block in the answer | 2 of 3 | **0 of 3** |
| contradictory refusal | 1 of 3 | 0 of 3 |
| turn duration | 13.0 / 21.6 / 37.6 s | **4.0 / 6.1 / 7.2 s** |
| intent options | `{"top_n": 14}` | `{"top_n": 14, "group_by": "sector"}` |

And *"Show me the split by asset class."* →
`{"top_n": 14, "group_by": "asset_class"}`.

## 6. Out of scope

- The dividend tool (OD-5, spec `backend/0035`).
- Any change to the retry **count**; `GEMINI_MAX_ATTEMPTS` stays 3 and still applies to the failures a retry can repair.
- Raising `agent_max_tool_iterations`. Every measured turn used 1–2 of the 4 available.
