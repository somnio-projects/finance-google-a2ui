# 06 — Response shaping: who chooses the payload

Source of truth: [ADR-K](../adr/ADR-K-response-shaping.md), [`.claude/rules/backend/presentation.md`](../../.claude/rules/backend/presentation.md), [spec 0005](../../specs/backend/0005-presentation-layer.md), [spec 0012](../../specs/backend/0012-delivery-followups.md).

Solid = built. Dashed = planned, with the ticket that owns it.

```mermaid
flowchart TB
    subgraph callers["Three ways in, one registry"]
        cl["Flutter client · GET …/views<br/>?view=a&view=b + options"]
        batch["Flutter client · POST /v1/view-renders<br/>[{view, portfolio_id, options}] ≤ 8"]
        ag["Agent / model<br/>render intent {view, options}"]
    end
    reg{"Projection registry<br/>validate id + options"}
    rej["422 / 404 to the client · per-entry problem in a batch<br/>fallback + telemetry for the model"]
    sel["Selection rule<br/>(nobody chose → highest fitness)"]
    subgraph views["presentation/views/* — one module each"]
        v1["holdings.allocation.v1<br/>attribution.waterfall.v1<br/><i>fitness > 0 — selectable</i>"]
        v2["taxlots.table.v1 · scenario.comparison.v1<br/>payoff.curve.v1 · order.ticket.v1<br/><i>fitness = 0 — asked for by id, never volunteered</i>"]
        vn["…the next one: one new file"]
    end
    frag["fragments.py · displays.py<br/>series · bucket · category · total · *Display"]
    out["Payload the widget binds<br/>discriminated by `view`"]
    etag["Strong ETag + Cache-Control<br/>(resource, view, options, as_of) → 304"]
    a2ui["A2UI surface adapter"]
    cat["GET /v1/views catalog"]
    oa["OpenAPI oneOf + one example per view"]
    pf["Generated prompt fragments (GGU-14)"]
    doc["docs/catalog/CONTRACT.md<br/>regenerated, diffed in the gate"]

    cl --> reg
    batch --> reg
    ag --> reg
    reg -- "unknown / out of range / undeclared" --> rej
    reg -- "no preference" --> sel --> views
    reg --> views
    views --> frag
    views --> out
    out --> etag
    views --> a2ui
    views --> cat
    views --> oa
    views -.-> pf
    views -.-> doc
    v1 -.- vn
    v2 -.- vn

    %% Registering once publishes to five consumers; adding a chart touches
    %% only its own module (ADR-K D-14, D-15) — views/ is auto-discovered,
    %% so not even an import line is edited.
    %% The batch is a RESOURCE, not an RPC call: POST creates it, 201 returns
    %% it inline, and EVERY entry carries its own status, so one bad view
    %% never sinks the others (ADR-K D-18).
    %% The client's rejection is a 422/404; inside a batch it is that entry's
    %% problem document; the model's is a recorded fallback (ADR-K D-12).
    %% ETag covers the two GET reads only: a POST batch is not revalidated.
```

## Where each box lives

| Box | Code |
|---|---|
| Registry, Protocol | `backend/src/app/presentation/registry.py`, `spec.py` |
| Options and their bounds | `presentation/options.py` (`extra="forbid"`) |
| Fragments, `*Display` pairs | `presentation/fragments.py`, `displays.py`, `formatting.py` |
| Selection rule | `presentation/selection.py` (ranks each view's own `fitness`) |
| Serving endpoints, named once | `presentation/endpoints.py` |
| OpenAPI union, examples, catalog entry | `presentation/contract.py` |
| Prompt fragments | `presentation/prompt.py` |
| ETag · `If-None-Match` · 304 | `api/caching.py` (a dependency, reused per route) |
| The three callers | `api/v1/portfolio_views.py` · `api/v1/view_renders.py` · `services/render_intent_service.py` |
| Per-entry batch outcome | `services/view_render_service.py`, `schemas/view_renders.py` |
