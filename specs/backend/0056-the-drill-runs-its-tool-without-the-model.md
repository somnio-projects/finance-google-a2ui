# 0056 — The drill runs its tool without the model, and today's walk offers it

- **Area:** backend
- **Status:** In progress
- **Ticket:** [GGU-161](https://somniosoftware.atlassian.net/browse/GGU-161) (QA: GGU-31 AC-1 is not met on the deployed app)
- **Also:** [0022](0022-surface-actions.md) (surface actions, `drill.attribution.v1`), [0032](0032-attribution-headline-and-driver-detail.md) (`driver_detail`, `attribution.driver.v1`), [0039](0039-the-surface-answers-the-question-that-was-asked.md) (`attribution.window.v1`), [0053](0053-the-agent-speaks-a2ui-v1.md) (the v1.0 `action`), [frontend/0040](../frontend/0040-a-selected-bar-offers-the-drill.md), [frontend_v1/0002](../frontend_v1/0002-a-selected-bar-offers-the-drill.md)
- **Owner:** Lautaro Bertuzzi · **Date:** 2026-11-12

## 1. Problem

GGU-31 AC-1: *"Tapping a waterfall segment emits a drill event and the agent
returns a deeper attribution surface."* On the deployed app it does not. Flow
A's question, *"What moved my portfolio today?"*, is answered by
`compute_attribution`, which since spec 0039 attaches `attribution.window.v1`
— and that projection **declares no actions**. The client reads the drill's
`choices` from the payload (frontend/0011 OD-4), finds none, and keeps the tap
to itself: the bar selects, nothing is sent. Measured on `develop`:

| view | rendered by | declares `drill.attribution.v1` |
|---|---|---|
| `attribution.waterfall.v1` (all time) | the REST read, the selection rule | yes |
| `attribution.window.v1` (a window) | `compute_attribution` — every agent turn about a move | **no** |

Second, even where the drill was sent, what ran was a **model turn**: the
action composed *"Break down the contribution of BTC…"* and the model had to
choose `driver_detail` itself. That choice is the only step of the drill that
was not deterministic, and nothing about it needs a model — the tap already
names the tool's one argument.

## 2. What ships

- **AC-1 — today's walk declares the drill.** `attribution.window.v1` publishes
  `drill.attribution.v1` in `actions` (payload) and `props.actions` (A2UI),
  derived by `declared_action` like the all-time walk's, **when the window is
  `1d`**. For `7d` and `30d` it publishes `actions: []` (OD-2).
- **AC-2 — an action may pin a direct call.** `SurfaceActionSpec` gains
  `direct: Callable[[args], DirectCall] | None` (default `None`). A
  `DirectCall` names a registered tool, its arguments (built from the
  action's **validated** arguments, never from the caller's raw map) and the
  backend sentence that narrates the result.
- **AC-3 — a direct turn calls no model.** `SurfaceActionService.turn_for`
  returns `ComposedTurn(prompt, direct)`; both A2A adapters pass `direct` to
  the turn, and `AgentService.run_turn_events(direct=…)` runs exactly that tool
  through the same `execute_tool` (validation, render resolution, telemetry),
  emits its surface, and completes with the narration. `ModelClient.generate`
  is never awaited; the turn records `iterations=0`, `tool_calls=1`.
- **AC-4 — `drill.attribution.v1` pins `driver_detail`.** `{symbol: driver}`;
  the answer is the held sentence filled from the tool's own `*Display`
  strings, the not-held leaf (*"X is not held in this portfolio…"*), or a
  fixed failure sentence when the tool returned an error marker. The surface
  is `attribution.driver.v1` for that symbol.
- **AC-5 — v0.9 and v1.0 alike.** `message/stream` with a `data` part and
  `POST /a2ui/v1/a2a` with `action(drill_attribution)` both stream the
  `DriverDetail` surface with no model call.
- **AC-6 — chips are unchanged.** `ask.suggested.v1` declares no direct call:
  a chip is a question, and answering it is the model's job.
- **AC-7 — the catalog moves with it.** `make catalog` regenerates
  `docs/catalog/CONTRACT.md`, `docs/catalog/view-catalog.snapshot.json` and
  the v1.0 catalog; both clients' copies follow.

## 3. Rulings

- **OD-1 — no model, rather than a pre-filled model turn.** The alternative
  was to inject the tool call into the history as though the model had made
  it and let the model narrate. Rejected: Gemini 3 rejects a `functionCall`
  part that carries no `thoughtSignature` (GGU-88, `infra/model/reply.py`),
  and a signature is opaque provider state we must never invent. The direct
  turn's narration is a backend f-string over the tool's display strings —
  the numbers-from-tools invariant with the model taken out of the one step
  that did not need it. The scripted model's drill entry (`demo_drill.py`)
  stays for a *typed* drill sentence and now reads the same template.
- **OD-2 — only today's window drills.** `attribution.driver.v1` is a day
  view by construction (`domain/driver.py`: price against previous close).
  Offering it from a 7-day walk would answer *"what did BTC do this week?"*
  with *today*. The all-time walk keeps its declaration (spec 0022) — the
  card says *today* in its own words there, which is what it has always done.
  A window driver is a new view, not a stretch of this one.
- **OD-3 — the way back is the transcript.** The drill is a turn appended to
  the conversation (frontend/0011): the waterfall it came from stays above it,
  still interactive, and its selection still drills. A *Back to attribution*
  action would re-render a surface that is already on screen one scroll up,
  and spend a turn to do it. No action is added for it.
- **OD-4 — `direct` builds from validated args.** The factory receives the
  action's arguments model after `validated_args`, so the tool's input is
  bounded by the same `Literal` the declaration publishes; `driver_detail`
  then validates `symbol` again against `Ticker`.

## 4. Contract, data, security, scope

- **API:** no new route, no new error. `actions[]` appears on
  `attribution.window.v1` (an additive DTO field, already the shape of
  `attribution.waterfall.v1`'s). Refusals are spec 0022's, unchanged: an
  undeclared driver is `-32602`, a disabled capability `-32601`, both before
  the stream opens.
- **Data:** none — no table, no migration.
- **Security:** the direct call's arguments come from the validated args
  model only; the client still names a value, never a tool, a view or a
  sentence (ADR-K D-3). Telemetry is spec 0022's: the action id, never the
  driver. Nothing new is logged.
- **Out:** a window-length driver detail (OD-2); a *Back* action (OD-3);
  direct calls for chips (AC-6).

## 5. Test decision

Unit: the direct turn awaits no model and emits the surface
(`test_agent_direct.py`); every narration branch; the action's direct call
names a tool the agent registry has; `turn_for` with and without `direct`;
both adapters forward `direct` (`test_a2a_actions.py`,
`test_a2ui_v1_service.py`); the window projection declares the drill for `1d`
only, in payload and props. Integration suite unchanged. 100 % branch
coverage, as the gate requires.
