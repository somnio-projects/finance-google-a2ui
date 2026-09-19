# 06 — Response shaping: who chooses the payload

Source of truth: [ADR-K](../adr/ADR-K-response-shaping.md), [`.claude/rules/backend/presentation.md`](../../.claude/rules/backend/presentation.md).

```mermaid
flowchart TB
    subgraph callers["Two callers, one registry"]
        cl["Flutter client<br/>?view=a&view=b + options"]
        ag["Agent / model<br/>render intent {view, options}"]
    end
    reg{"Projection registry<br/>validate id + options"}
    rej["422 / rejected<br/>telemetry + default view"]
    sel["Selection rule<br/>(nobody chose → pick from the data)"]
    subgraph views["presentation/views/* — one module each"]
        v1["holdings.allocation.v1"]
        v2["attribution.waterfall.v1"]
        v3["taxlots.table.v1"]
        vn["…the next one: one new file"]
    end
    frag["fragments.py<br/>series · bucket · total · *Display"]
    out["Payload the widget binds<br/>discriminated by `view`"]
    a2ui["A2UI surface adapter"]
    cat["GET /v1/views catalog"]
    oa["OpenAPI oneOf + examples"]
    pf["Generated prompt fragments (GGU-14)"]

    cl --> reg
    ag --> reg
    reg -- "unknown / out of range" --> rej
    reg -- "no preference" --> sel --> views
    reg --> views
    views --> frag
    views --> out
    views --> a2ui
    views --> cat
    views --> oa
    views --> pf

    %% Registering once publishes to four consumers; adding a chart
    %% touches only its own module (ADR-K D-14, D-15).
```
