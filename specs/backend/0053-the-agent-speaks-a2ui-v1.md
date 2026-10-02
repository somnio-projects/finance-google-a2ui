# 0053 — The agent speaks A2UI v1.0, beside v0.9

**Status:** In progress — approved by the TL 2026-10-01 · **Ticket:** *unassigned* (no GGU number yet) · **Area:** `backend/`
**Decision:** [ADR-M](../../docs/adr/ADR-M-a2ui-v1-wire.md) · **Pair:** [`frontend_v1/0001`](../frontend_v1/0001-a-second-client-renders-a2ui-v1.md)

## 1. Problem

The team is showing the showcase on A2UI v1.0 RC (2026-10-01). The agent
emits only a v0.9-era `render-intent` that the client resolves over REST, so
there is no A2UI message on the wire at all. `POST /a2a` must keep doing
exactly that for `frontend/`; v1.0 needs its own surface.

## 2. Scope

**In:** Patricio's plan M-05…M-15, scoped by ADR-M — the generated v1.0
catalog, composition rules and `Section`, the `renderView` function, catalog
`instructions`, the drift gate (as an `ARTIFACTS` entry), `POST /a2ui/v1/a2a`
emitting `createSurface` DataParts, the v1.0 agent card and negotiation, the
`callAgentFunction` handler, `drill_attribution` as an `action`, the scripted
client path (it already produces intents, so it inherits the wire), and
ticket + payoff composition.
**Out:** any change to `POST /a2a`, `/.well-known/agent-card.json`,
`render-intent`, `/v1/view-renders` or any projection's shape. ADK (not used
today; separate decision). `callRendererFunction` (no renderer-side function
the agent needs).

## 3. API contract

| Route | Verb | What |
|---|---|---|
| `/a2ui/v1/a2a` | POST | JSON-RPC `message/stream` over SSE. Text part → a turn. `DataPart(application/a2ui+json)` with `callAgentFunction` → deterministic render, no model. With `action` → a turn via `SurfaceActionService`. Bearer auth. |
| `/a2ui/v1/.well-known/agent-card.json` | GET | v1.0 card: `protocol_version: "1.0"`, extension `https://a2ui.org/a2a-extension/a2ui/v1.0`, `params.supportedCatalogIds: [CATALOG_ID]`. |
| `/a2ui/v1/catalog` | GET | The generated catalog document (same bytes as `docs/a2ui/v1.0/finance.catalog.json`). Bearer auth. |

SSE events on `/a2ui/v1/a2a`: `status-update` (unchanged shape),
`artifact-update` `{kind, taskId, contextId, artifact:{artifactId, parts:[DataPart]}}`
per surface or function response, terminal `message` (text + suggestions, no
`renderIntents`), `error`. Wire examples: `docs/a2ui/v1.0/examples/*.json` —
the **contract** the client binds; a change to one is a change to this spec.

## 4. Data model & migration

None. No table, no migration.

## 5. Security notes

**One new public route:** `GET /a2ui/v1/.well-known/agent-card.json`, public for the reason the v0.9 card is (spec 0010 OD-1 — a client cannot present a token before it bootstraps); it carries no subject data. Listed in `.claude/rules/backend/security.md` and `test_openapi_contract.py::PUBLIC`. `GET /a2ui/v1/catalog` and `POST /a2ui/v1/a2a` require a bearer.

Same auth dependency as `/a2a`. `renderView` args are the projection's
declared options only (ADR-K D-3): unknown view, unknown option, out of range
→ `INVALID_FUNCTION_CALL`, logged without the args. `componentId` is bounded
to `^[A-Za-z_][A-Za-z0-9_]{0,31}$`. A `callAgentFunction` never reaches the
model (asserted with the null model client). RFC 9457 for HTTP faults.

## 6. Acceptance criteria

- **AC-1** Every message the endpoint emits, and every file in
  `docs/a2ui/v1.0/examples/`, validates against the vendored v1.0 schemas
  with `catalog.json` resolved to the generated finance catalog.
- **AC-2** The generated catalog validates against `catalog_definition.json`,
  has one component per A2UI component name in the registry plus `Section`,
  UAX #31 names, no `theme`, composition rules per ADR-M D-4, and the
  `renderView` function per D-6. `make catalog` writes it; the gate fails on drift.
- **AC-3** A turn whose tools emit N intents streams N `createSurface` parts
  in order, each `dataModel.root.payload` equal to the REST payload for the
  same view and options.
- **AC-4** Ticket + payoff in one turn → one surface, payoff as child; a second payoff, or a payoff with no ticket before it, is not drawn (the catalog forbids it at the root). **Dormant today:** no tool emits `payoff.curve.v1` (`agent/tools/payoff.py` emits no render intent), so this is proven with test tools only and becomes live the day one does.
- **AC-5** `callAgentFunction(renderView)` answers `agentFunctionResponse` +
  `updateDataModel` matching the examples; invalid options and unknown
  function answer the error codes; the model is never called.
- **AC-6** `action(drill_attribution)` opens a turn with the composed prompt;
  bad args are refused as today.
- **AC-7** Missing/foreign `a2uiRendererCapabilities` → JSON-RPC error naming
  `CATALOG_ID`.
- **AC-8** `POST /a2a`, its card and every v0.9 behaviour test are unchanged. The only existing tests edited are the three registration inventories that exist to fail on exactly this: `test_openapi_contract.py::PUBLIC` (+ the v1.0 card), `test_openapi_document.py` (24 → 27 operations) and `test_catalog_snapshot.py` (`ARTIFACTS` gains the catalog).

## 7. Test plan

Unit: catalog generator, composition rules, message builders, `renderView`
handler, negotiation. Integration: SSE stream for the three demo flows on the
scripted client. Schema conformance with `jsonschema` (dev dependency, added
with `uv add --dev`). 100 % branch coverage, ≤150 lines per file.

## 8. Open decisions

ADR-M OD-1…3.

## 9. Rollout & observability

Dark until `frontend_v1` ships; the route exists in every environment. Turn
telemetry tags `wire=a2ui-v1.0`.
