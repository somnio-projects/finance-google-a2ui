# ADR-M — A2UI v1.0 wire, beside v0.9 and not instead of it

**Status:** Proposed · **Date:** 2026-10-01 · **Deciders:** Lautaro Bertuzzi (TL), Patricio Burzaco (PM)
**Specs:** [`backend/0053`](../../specs/backend/0053-the-agent-speaks-a2ui-v1.md) · [`frontend_v1/0001`](../../specs/frontend_v1/0001-a-second-client-renders-a2ui-v1.md)
**Upstream:** A2UI v1.0 *Candidate*, `a2ui-project/a2ui` @ `e83e074` (2026-09-29), schemas vendored in [`docs/a2ui/v1.0/schemas/`](../a2ui/v1.0/schemas/) (Apache-2.0)

## Context

On 2026-10-01 the team decided to show the showcase on A2UI **v1.0 RC**
(Patricio's plan, *"Migración a A2UI 1.0 RC — análisis y plan de acción"*).
Two facts shaped how:

1. **Nothing that runs on v0.9 may change.** `frontend/`, its URL
   (`finance-a2ui.web.app`), `POST /a2a` and the `render-intent` event are
   the delivered showcase, and they are the fallback if the RC moves. v1.0 is
   built **beside** them: a second client and a second agent endpoint.
2. **No public Flutter renderer speaks v1.0.** `genui` 0.10.4 is on v0.9;
   `a2ui_core` 0.2.2 validates v1.0 but its `MessageProcessor` still accepts
   only v0.9 (a2ui-project/a2ui#2899 is the plan to change that, Phase 1 of 3).

## Decision

**D-1 — The renderer is ours, in pure Dart, with no A2UI dependency.** The new
client implements the subset of v1.0 this catalog uses (envelope parsing,
surface state, adjacency-list tree, JSON-Pointer data model, composition
rules, `callAgentFunction`, `action`, `error`) in a pure-Dart package. The
blocker stops being one: we do not wait for `genui` or `a2ui_flutter`, and we
add no alpha package to a gate. Conformance is proven against the **official
schemas**, vendored, by both sides (D-6). Moving to `a2ui_flutter` when it
ships is a later, optional change behind the same package API.

**D-2 — Additive backend.** A new route `POST /a2ui/v1/a2a` (JSON-RPC
`message/stream` over SSE, same auth) and a new agent card at
`GET /a2ui/v1/.well-known/agent-card.json`. Both **reuse** the agent loop, the
tools, the projections and `RenderIntentService` unchanged; only the last
step — how a validated render intent becomes bytes — is new. `POST /a2a` and
its card keep answering v0.9 byte-for-byte.

**D-3 — One surface per render intent; one component per projection.** For
each validated intent the agent emits an A2A `artifact-update` whose artifact
is one `DataPart` (`metadata.mimeType: application/a2ui+json`) holding one
`createSurface` with inline `components` and `dataModel`:

- `surfaceId` = `<taskId>-<index>`; `catalogId` = `CATALOG_ID` (D-5).
- Component `id: "root"`, `component` = the projection's existing A2UI
  component name (`PortfolioSummary`, …), `data: {"path": "/root"}`,
  `accessibility.label` set.
- `dataModel.root` = `{"view", "options", "payload"}` where `payload` is the
  projection's DTO exactly as `GET /v1/portfolios/current/views` serves it.
  The client still transforms nothing (ADR-K).

The terminal `message` event keeps the text part and the suggestion chips and
drops `renderIntents`. Canonical examples: [`docs/a2ui/v1.0/examples/`](../a2ui/v1.0/examples/).

**D-4 — Composition.** When a turn emits an order ticket (`order.ticket.v1|v2`)
**and** `payoff.curve.v1`, they become **one** surface: the ticket is `root`
with `children: ["payoff"]`, the curve is component `payoff` bound to
`/payoff`. The catalog declares `RiskPayoffChart.allowedParents =
[OrderTicket, MultiLegOrderTicket]`, `DriverDetail.allowedParents =
[Surface, AttributionWaterfall]`, every other component `[Surface, Section]`,
and `Section` (layout, `children`) `allowedParents = [Surface]`. The renderer
enforces them and reports `UNALLOWED_PARENT` / `UNALLOWED_CHILD`.

**D-5 — The catalog is generated.** `CATALOG_ID =
https://somniosoftware.com/a2ui/finance-showcase/v1.0/catalog.json`.
`docs/a2ui/v1.0/finance.catalog.json` is rendered from the projection registry
(`protocolVersion: "1.0"`, `$id` = `catalogId`, `components` map with
composition rules, `functions` map, `instructions` from the existing guidance)
and is a new entry in `presentation/catalog_artifacts.ARTIFACTS` — gated by
regeneration like `CONTRACT.md`, never a new gate step. No `theme`: theming
lives in Flutter `ThemeData` (v1.0 removed it from the wire).

**D-6 — Edits are `callAgentFunction("renderView")`, never the model.** The
catalog declares one function, `renderView(componentId, view, options)`,
`returnType: object`, `allowedCallers: rendererOnly` (only a renderer may
invoke it), and the renderer does not register it locally — so it routes to
the agent. The renderer sends a `DataPart` with `callAgentFunction` on
`POST /a2ui/v1/a2a`; the agent validates `options` against the projection's
own options model (ADR-K D-3), renders deterministically **without the LLM**,
and answers `agentFunctionResponse{value:{componentId, view}}` followed by
`updateDataModel{path:"/<componentId>", value:{view, options, payload}}`.
Invalid options → `agentFunctionResponse.error.code = "INVALID_FUNCTION_CALL"`;
unknown function → `"UNKNOWN_FUNCTION"`.

**D-7 — New turns are v1.0 `action`s.** `drill.attribution.v1` arrives as
`action{name:"drill_attribution", context:{driver}}` and is resolved by the
existing `SurfaceActionService` (same args model, same composed prompt).
Suggestion chips live outside any surface, so a chip is sent as the chip's
text in an ordinary text part — no v1.0 message pretends a surface exists.

**D-8 — Negotiation.** The v1.0 card advertises extension
`https://a2ui.org/a2a-extension/a2ui/v1.0` with `params.supportedCatalogIds:
[CATALOG_ID]`. The renderer sends `X-A2A-Extensions` with that URI and
`message.metadata.a2uiRendererCapabilities = {"v1.0":{"supportedCatalogIds":[CATALOG_ID]}}`.
A request on `/a2ui/v1/a2a` whose capabilities do not include `CATALOG_ID`
is refused with a JSON-RPC error naming the catalog, never answered in prose.

**D-9 — The same app, upgraded, at a second URL.** `frontend_v1/` is a copy of
`frontend/` with only the assistant's wire moved to v1.0, on the same backend,
database and Firebase project/web app. It is a separate Flutter app: own pub workspace, own `.fvmrc` (same pinned SDK), own gate part
`frontend_v1.*`, own `frontend-v1-ci.yaml`, own specs area, own Firebase
Hosting site (`finance-a2ui-v1` → https://finance-a2ui-v1.web.app, created 2026-10-01). It may depend on `frontend/packages/*` **read-only** through
path dependencies; it never edits `frontend/`. Widgets that live in
`frontend/app/lib` are copied, not imported (an app cannot be a dependency),
and the copy is recorded as such.

## Consequences

- Two A2A surfaces exist on purpose until the team retires one. The REST
  endpoints are shared and unchanged.
- The renderer is a maintained piece of ours; #2899 landing makes it optional,
  not obsolete-on-arrival, because the package API stays.
- Supersedes nothing: ADR-D D-2 ("v0.9 only") stays true **for `/a2a`**;
  this ADR scopes v1.0 to `/a2ui/v1/*`.

## Open

- **OD-1** ~~Hosting site id~~ — resolved: `finance-a2ui-v1`, created 2026-10-01, auth domain authorized, dev CORS widened (`infra/environments/dev.tfvars`).
- **OD-2** Does `genui` publish v1.0 before the video? Ask Google; D-1 holds either way.
- **OD-3** ~~SSO allow-list~~ — answered 2026-10-01: dev enrols any verified Google/e-mail-link identity as a member (`AUTH_OPEN_ENROLMENT=true`); the v1.0 client shares that auth.
