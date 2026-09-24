# 0029 — The turn recommends its chips, and the client can tap them

- **Area:** backend (+ frontend/0011 for the client half)
- **Status:** In progress
- **Ticket:** _unassigned — no GGU number exists for this yet; none is invented here (see 0025 §6)_
- **Also:** [0022](0022-surface-actions.md) (surface actions: `ask.suggested.v1`, `drill.attribution.v1`, §3.3, OD-1), [0010](0010-a2a-surface.md) (the A2A stream), [0006](0006-agent-host.md) (the turn loop), [ADR-J](../../docs/adr/ADR-J-a2a-transport.md), [ADR-K](../../docs/adr/ADR-K-response-shaping.md) D-12
- **Owner:** Lautaro Bertuzzi · **Date:** 2026-09-22

## 1. Problem

`FlowA-Assistant.dc.html`, `FlowB` and `FlowC` all end the same way: a row of
follow-up chips above the composer — *Why did NVDA move? · Show as % of return
· Compare to the S&P 500*. Spec 0022 built the mechanism a chip needs
(`ask.suggested.v1`: the client sends a registered key, the turn receives the
registered sentence) and ruled that **the agent cannot invent a chip** (OD-1).
It did not say *which* chips a turn ends with, so nothing publishes any, and
the client has nothing to draw.

The same spec left `SHIPPED_ENABLED = False` "until a client can send a `data`
part". frontend/0011 is that client.

## 2. What ships

- **`TurnResult.suggestions`** — the registered suggestion keys the turn
  recommends, in table order. The terminal `message` event carries them as
  `"suggestions": [{"key": "...", "label": "..."}]` beside `renderIntents`,
  label included so the client draws words it did not write (N-9).
- **`recommended(prompt)`** in `app/actions/suggestions.py`: every curated
  key except the one whose registered prompt *is* this turn's prompt — a chip
  is never offered to re-ask what was just asked. Deterministic, no model
  involvement: the curated table is the whole universe (0022 OD-1), so the
  only choice left is "not the same one again".
- **`SHIPPED_ENABLED = True`.** The client half exists, so the declaration
  appears: `attribution.waterfall.v1` publishes `drill.attribution.v1` in its
  `actions`, `GET /v1/views` and both catalog artefacts regenerate, and the
  flag's default flips to on. A tapped bar and a tapped chip both run.
- The OpenAPI stream example gains the field; the A2A adapter's tests pin it.
- **CORS admits `X-A2A-Extensions`.** The client sends it on every turn (the
  A2UI extension declaration, ADR-J); the allow-list did not name it, so a
  browser's preflight to `/` answered *400 Disallowed CORS headers* and the
  Assistant reported *the agent could not be reached* while `curl` — which
  never preflights — worked. A test now preflights `/` with exactly the
  headers the client sends.

## 3. Rulings

- **OD-1 — the recommendation is a table walk, not a model call.** 0022 fixed
  the universe to four curated sentences; asking a model to pick three of
  four would add a network round trip to decide almost nothing, and the
  `NullModelClient` path — the one every local stack runs — would then have no
  chips at all. The design's chips are context-specific gallery data; ours
  are the curated set minus the question just asked.
- **OD-2 — labels travel with keys.** The client could look labels up in the
  frozen catalog, but a chip label is a sentence the backend owns and may
  change; sending it on the wire keeps one source. The key is what comes
  back, exactly as 0022 §3.3 requires.
- **OD-3 — flipping the capability is this spec's, not a footnote.** The
  capability docstring names GGU-31/32 as the tickets that flip it; those
  numbers were never assigned in Jira. The flip is recorded here, with the
  client PR that justifies it.

## 4. Test decision

Unit: `recommended` over each curated prompt and over a free-text prompt;
the terminal event carries `suggestions` with labels from the table; the
loop's result carries them; the documented stream example round-trips
through the builders' keys (existing `test_a2a_examples` suite). The catalog
is regenerated and both artefacts committed; the frontend catalog test sees
`actions` on the waterfall.
