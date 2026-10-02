# 14 — How an agent turn reaches the v1.0 client

The v1.0 path runs beside v0.9 and shares only what sits behind the turn. Source of truth: [ADR-M](../adr/ADR-M-a2ui-v1-wire.md), [`backend/0053`](../../specs/backend/0053-the-agent-speaks-a2ui-v1.md), [`frontend_v1/0001`](../../specs/frontend_v1/0001-a-second-client-renders-a2ui-v1.md), the wire examples in [`docs/a2ui/v1.0/examples/`](../a2ui/v1.0/examples/). Diagram [05](05-agent-turn.md) draws the turn itself; this one draws only what differs after it.

```mermaid
flowchart LR
    subgraph clients["Clients"]
        v09["frontend/ · v0.9<br/>finance-a2ui.web.app"]
        v10["frontend_v1/ · v1.0<br/>a2ui_v1 renderer (ours, pure Dart)"]
    end

    subgraph svc["Our service · backend/"]
        a2a["POST /a2a<br/>render-intent + REST fetch"]
        a2a1["POST /a2ui/v1/a2a<br/>createSurface DataParts"]
        fn["renderView handler<br/>callAgentFunction · no model"]
        turn["Agent turn<br/>tools · RenderIntentService"]
        reg["Projection registry<br/>12 views · options models"]
        cat["finance.catalog.json<br/>generated · gated"]
    end

    v09 --> a2a --> turn
    v10 -- "text · action" --> a2a1 --> turn
    v10 -- "callAgentFunction" --> a2a1 --> fn
    turn --> reg
    fn --> reg
    reg --> cat
    cat -. "composition rules" .-> v10

    %% Both A2A routes reach the same turn and the same registry: the only new
    %% backend code is how a validated intent becomes bytes, plus the function
    %% handler. An edit (callAgentFunction) never reaches the model — that is
    %% the numbers rule, enforced by the route, not by the prompt.
    %% There is no genui on either side: no public Flutter renderer spoke v1.0
    %% on 2026-10-01 (a2ui-project/a2ui#2899), so the renderer is ours.
```

**Not drawn:** the REST read endpoints, which both clients may call and which
did not change; the v1.0 Hosting site, which needs a site created by a human
(ADR-M OD-1) before it is drawn as deployed.
