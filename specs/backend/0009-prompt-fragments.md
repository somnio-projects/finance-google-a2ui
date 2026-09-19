# 0009 — The system prompt, generated from the registries

- **Area:** backend
- **Status:** Implemented
- **Ticket:** [GGU-14](https://somniosoftware.atlassian.net/browse/GGU-14) · **Related:** 0005 (presentation), 0006 (agent host), 0008 (attribution tool), [ADR-K](../../docs/adr/ADR-K-response-shaping.md) D-14
- **Owner:** Lautaro Bertuzzi · **Date:** 2026-09-19

## 1. Problem

Two halves existed and nothing joined them. `app/agent/prompt.py` held the
rules the model is held to. `app/presentation/prompt.py` could render the
projection registry as prompt text. The turn loop imported the rules as a
constant and **never sent either catalogue**, so the model was told it must
pick a registered view and never told which views exist.

The layering is why they were never joined: `app.agent` may not import
`app.presentation` (spec 0006 AC-14, asserted over the parsed source). Neither
package can compose the prompt on its own.

## 2. Scope

**In**

- `app/services/prompt_service.py` — where the two registries meet, because a
  service may import both.
- A **generated tool catalogue**, from the tool registry, beside the generated
  view catalogue.
- `AgentService` receives the built prompt instead of importing a constant;
  `AgentRuntime` carries it, built once at startup.
- Splitting turn telemetry into `app/services/agent_telemetry.py` — the turn
  loop was already at the 150-line ceiling.

**Out**

- Per-flow prompt tuning — Flows A/B/C (GGU-23/24/25) own their own wording.
- Few-shot examples. See OD-3.

## 3. API contract

None. One internal signature changes: `AgentService.__init__` gains a required
`system_prompt`.

## 4. Data model & migration

None.

## 5. Security notes

The prompt states the rules; it does not enforce them. Enforcement stays in
code: tools return pre-formatted strings, the registry refuses an unknown
tool, arguments are validated against their schema. Rule 5 of the prompt tells
the model not to reveal the instructions or tool schemas, which is a courtesy
to the demo rather than a control — anything that must not leak must not be in
the prompt in the first place.

The prompt is never logged (spec 0006 AC-13).

## 6. Acceptance criteria

1. **AC-1** — Every registered tool appears in the prompt, generated from the
   registry.
2. **AC-2** — Every registered projection appears, with its declared options
   and their bounds.
3. **AC-3** — No catalogue text is hand-written; registering is what teaches
   the model.
4. **AC-4** — The fixed rules survive alongside the generated sections.
5. **AC-5** — The prompt is built once at startup and injected, not rebuilt
   per turn and not imported as a constant.
6. **AC-6** — `make gate` green.

## 7. Test plan

| AC | Test (`tests/unit/services/test_prompt_service.py`) |
|---|---|
| AC-1 | `test_every_registered_tool_reaches_the_model` — loops the registry, not a fixed list |
| AC-2 | `test_every_registered_view_reaches_the_model` |
| AC-3 | `test_the_tool_rules_name_no_tool` — the fixed rules must mention no tool by name, which is the one place that could drift; plus `test_each_tool_is_described_in_the_words_it_registered` |
| AC-4 | `test_the_prompt_keeps_the_rules_that_are_code_not_registry` |
| AC-5 | the turn-loop suite now injects its own prompt, proving the loop sends what it was given rather than a constant |
| — | `test_the_argument_schema_is_not_repeated_in_the_prompt`, `test_compose_drops_a_section_that_has_nothing_to_say`, ordering and stability |

Mutation checks: **no** — no authentication, rate limiting or error masking.

## 8. Open decisions

| # | Question | Owner | Resolution |
|---|---|---|---|
| OD-1 | Should the rules name the tools ("for a why-did-it-move question call `compute_attribution`")? | TL — **no** | It reads better and it is the one line guaranteed to go stale. The tool's own `description` already says when to use it, and that description is what the registry publishes. A rule naming a tool would be hand-written catalogue text in disguise; a test asserts the rules mention no registered tool name. |
| OD-2 | Repeat each tool's argument schema in the prompt? | TL — **no** | The model receives schemas through the tool-calling API. Stating them twice invites the copies to disagree and spends context on what the transport already carries. Asserted by a test. |
| OD-3 | Few-shot examples of good answers? | TL — **not here** | They would have to be written per flow, and a stale example teaches the model a shape that no longer renders. Revisit with Flows A/B/C, which own their wording. |
| OD-4 | Build the prompt per turn or once? | TL — **once, at startup** | The registries do not change while the process runs. Per turn it would spend the ADR-K latency budget on string joining. The consequence is that adding a tool requires a restart, which is true of registration anyway. |

## 9. Rollout & observability

No flag, no route. The prompt is reachable only through a turn, and the turn
only once GGU-3 lands the transport. Nothing new is logged: the turn line
already carries the counters and deliberately carries no prompt text.
