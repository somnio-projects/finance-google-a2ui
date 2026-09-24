# 0039 — The surface answers the question that was asked

- **Area:** backend (the presentation registry and one agent tool), frontend (one component registration)
- **Status:** In progress
- **Ticket:** _unassigned — no GGU number exists for this; none is invented here_
- **Also:** [ADR-K](../../docs/adr/ADR-K-response-shaping.md) D-11/D-12 (the model picks from the registry), [ADR-L](../../docs/adr/ADR-L-client-architecture.md) D-3 (the component seam), [`backend/0005`](0005-agent-turn.md) AC-5 (the waterfall)
- **Owner:** Lautaro Bertuzzi · **Date:** 2026-09-23

## 1. Problem

The TL, reading the deployed app: *"esta conversación tiene sentido o sigue sin
sentido? es medio estúpido re mostrar el mismo chart con la contestación si no
te lo está pidiendo explícitamente."*

Three turns against the live build (`0.1.0+5cb9a40`, real Gemini
`gemini-3.8-flash`, seeded data), reproduced locally before anything was
changed:

| Asked | Surface attached | What the sentence said |
|---|---|---|
| *What moved my portfolio today?* | `attribution.waterfall.v1` — all-time, Net **+$61,204.05** | **today** +$3,240.18 (0.68%), NVIDIA **+$4,370.40** |
| *Why did I move?* | `attribution.waterfall.v1` — **the same chart again** | **the week** −$8,248.86, NVIDIA **−$7,871.40** |
| *Tax lots* | `holdings.allocation.v1` — a donut of 14 holdings | *"Please specify which holding and the quantity… FIFO, LIFO, or HIFO"* |

The second row is the sharp one: the chart named NVIDIA the **biggest
contributor** and the sentence directly above it named NVIDIA the **biggest
detractor**. Both were correct about different quantities.

**The cause is one line.** `agent/tools/attribution.py` computes
`attribute_window(...)` — a move over 1, 7 or 30 days — and returned
`RenderIntent(view="attribution.waterfall.v1")`. That projection is
*unrealised P/L, walked*: it compares each holding to what it **cost**. Its
options model has no concept of a window, so no argument could have fixed the
call. `domain/attribution.py` has said they are different questions since it
was written:

> *"This answers 'why did my portfolio move over the last week?', which is a
> different question from the unrealised profit and loss a holding carries."*

The domain knew. The presentation layer only ever had the other one.

## 2. Rulings

- **OD-1 — a new view id, not an option on the old one.** `/v1` is a
  contract, and the all-time walk remains the right answer to *how much am I
  up on each holding?* Two questions, two ids. `attribution.window.v1` takes a
  bounded `window` option and renders what the tool computed.

- **OD-2 — the same component name.** The A2UI adapter emits
  `AttributionWaterfall`, the name design already owns. This is design's
  waterfall drawing a different quantity, not a second widget — so
  `DESIGN_CATALOG` gains an entry whose *value* design wrote, and the client
  adds a registration and no new painter. Inventing a name design never wrote
  would have been the thing `test_component_names.py` exists to prevent.

- **OD-3 — the step is its own type.** Reusing `HoldingStep` was tried and
  pydantic refused it: that step carries `units` (a quantity) and `price` (a
  unit price), which a window contribution does not have. `WindowStep` carries
  `opened` and `closed` instead. Bending money into a field typed as a
  quantity to save a class is how a contract stops being readable.

- **OD-4 — the render intent carries the window.** Without it the surface
  would draw its default while the sentence described another — the same
  defect one layer down.

- **OD-5 — the windows are declared twice, and compared by a test.**
  `app.agent` may import nothing outside `app.core` and `app.domain` (spec
  0006 AC-2); importing the projection's declaration was tried and the
  boundary test refused it, correctly. So the tool keeps its literal and
  `test_attribution_windows_agree.py` compares the two — the standard answer
  here to a property spanning two layers.

- **OD-6 — the all-time walk is now unreachable by the agent, and that is
  declared.** `test_catalog_reach.py` caught it immediately, which is what it
  is for. It moves to `CLIENT_ONLY`: a screen the client asks for by id, not
  an answer to a turn. Giving the agent a second door — a `window: "all"`
  argument — was considered and rejected: it is a different computation, not
  a wider window, and bolting it on is how the two got confused to begin with.

- **OD-7 — two views may share a component, and the test helper now says so
  out loud.** `CatalogSnapshot.entryFor(component)` used `firstWhere`, so with
  two views under one name it would have handed a test the **wrong example
  and passed**. It now throws on an ambiguous name and `entryForView(viewId)`
  is the way to ask. That is the same class of silent wrongness GGU-53 was
  written for, met on the way past.

- **OD-8 — what this spec does NOT fix.** *"Tax lots"* still reaches
  `simulate_sale` and answers with a clarification under an unrelated donut,
  and no answer refers to the previous turn (*"You moved because…"*). Both
  are real and both are the TL's words; neither is an attribution problem and
  neither is closed here. They are named so the next person does not read a
  green gate as a fixed conversation.

## 3. Acceptance criteria

1. **AC-1** — asked about a window, the attached surface carries that window's figures.
2. **AC-2** — the title and the net annotation name the period in words the backend wrote.
3. **AC-3** — the steps sum to the headline, and the last running total is where the walk ends.
4. **AC-4** — an unknown window is a 422, and `window` is a real query parameter on the views endpoint.
5. **AC-5** — the tool's window set and the projection's are identical.
6. **AC-6** — the client draws it with no new painter, resolving its example by view id.
7. **AC-7** — `cd backend && make gate` and `cd frontend && make gate` both green.

## 4. Test plan

| AC | How |
|---|---|
| 1 | `test_attribution_window.py` — the payload's figures compared against `attribute_window`'s own result, and against the all-time walk's, which must differ |
| 2, 3 | the same file: period in the title and the annotation; the bars summed |
| 4 | `test_attribution_window_contract.py` and `test_view_query_options.py` |
| 5 | `test_attribution_windows_agree.py` |
| 6 | `attribution_window_component_test.dart`, `catalog_contract_test.dart` |
| all | **measured end to end**: the same three questions, the same agent, before and after |

## 5. Out of scope

Everything in OD-8, and the repetition itself: a turn still attaches one
surface per tool call, so two questions answered by the same tool still draw
two charts. Whether a turn should suppress a surface it has already shown is
a product decision about the conversation, not about attribution.
