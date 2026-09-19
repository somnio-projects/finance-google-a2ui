# 06 — Response shaping: who chooses the payload

Source of truth: [ADR-K](../adr/ADR-K-response-shaping.md), [`.claude/rules/backend/presentation.md`](../../.claude/rules/backend/presentation.md), [spec 0005](../../specs/backend/0005-presentation-layer.md).

Solid = built (GGU-49). Dashed = planned, with the ticket that owns it.

```mermaid
flowchart TB
    subgraph callers["Two callers, one registry"]
        cl["Flutter client<br/>?view=a&view=b + options"]
        ag["Agent / model<br/>render intent {view, options}"]
    end
    reg{"Projection registry<br/>validate id + options"}
    rej["422 to the client · fallback + telemetry<br/>for the model"]
    sel["Selection rule<br/>(nobody chose → highest fitness)"]
    subgraph views["presentation/views/* — one module each"]
        v1["holdings.allocation.v1"]
        v2["attribution.waterfall.v1"]
        vn["…the next one: one new file"]
    end
    frag["fragments.py · displays.py<br/>series · bucket · category · total · *Display"]
    out["Payload the widget binds<br/>discriminated by `view`"]
    a2ui["A2UI surface adapter"]
    cat["GET /v1/views catalog"]
    oa["OpenAPI oneOf + one example per view"]
    pf["Generated prompt fragments (GGU-14)"]

    cl --> reg
    ag --> reg
    reg -- "unknown / out of range / undeclared" --> rej
    reg -- "no preference" --> sel --> views
    reg --> views
    views --> frag
    views --> out
    views --> a2ui
    views --> cat
    views --> oa
    views -.-> pf
    v1 -.- vn
    v2 -.- vn

    %% Registering once publishes to four consumers; adding a chart touches
    %% only its own module (ADR-K D-14, D-15) — views/ is auto-discovered,
    %% so not even an import line is edited.
    %% The client's rejection is a 422; the model's is a recorded fallback
    %% to the endpoint default (ADR-K D-12).
```

## Where each box lives

| Box | Code |
|---|---|
| Registry, Protocol | `backend/src/app/presentation/registry.py`, `spec.py` |
| Options and their bounds | `presentation/options.py` (`extra="forbid"`) |
| Fragments, `*Display` pairs | `presentation/fragments.py`, `displays.py`, `formatting.py` |
| Selection rule | `presentation/selection.py` (ranks each view's own `fitness`) |
| OpenAPI union + examples | `presentation/contract.py` |
| Prompt fragments | `presentation/prompt.py` |
| The two callers | `api/v1/portfolio_views.py` · `services/render_intent_service.py` |
