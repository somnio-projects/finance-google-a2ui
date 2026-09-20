# 11 — Client architecture

What the Flutter client is made of, and what each layer is allowed to reach. Source of truth: [`.claude/rules/client/architecture.md`](../../.claude/rules/client/architecture.md), [`.claude/rules/client/presentation.md`](../../.claude/rules/client/presentation.md), [ADR-I](../adr/ADR-I-client-routing.md), [ADR-K](../adr/ADR-K-response-shaping.md).

```mermaid
flowchart TB
    subgraph device["Browser / device — untrusted, ships to the user"]
        gate["auth gate<br/>ONE component (ADR-I D-3)"]
        view["features/&lt;f&gt;/view<br/>widgets — bind, never transform"]
        bloc["features/&lt;f&gt;/bloc<br/>state; no flutter/material"]
        repo["features/&lt;f&gt;/repository<br/>the only caller of the network"]
        conn["genui_a2a connector<br/>mutable header map: Bearer + X-A2A-Extensions"]
        cfg["config/AppConfig<br/>the only reader of --dart-define"]
        thm["theme/<br/>ColorScheme + FinanceTokens"]
    end
    subgraph svc["Our backend — Cloud Run"]
        card["GET /.well-known/agent-card.json<br/>unauthenticated by contract"]
        a2a["POST / — JSON-RPC message/stream<br/>surfaces stream in (ADR-D)"]
        views["GET /v1/views · /v1/portfolios/{id}/views<br/>POST /v1/view-renders"]
        pres["presentation/ projections<br/>every figure already a *Display string"]
    end
    subgraph goog["Google — Firebase"]
        fb["Firebase Auth<br/>issues the ID token"]
    end

    thm --> view
    view --> bloc --> repo
    cfg --> repo
    repo --> conn
    conn --> a2a
    repo --> views
    conn --> card
    pres --> views
    pres --> a2a
    gate -.->|"(planned) GGU-2 — login is a simulated<br/>delay-then-success today"| fb
    fb -.->|"(planned) ID token, rewritten into the<br/>header map before each send (ADR-B D-9)"| conn

    %% The three edges that do NOT exist, and are review blockers if they appear:
    %%   view --> repo   a page holding a repository; the missing piece is a state field
    %%   bloc --> conn   business logic reaching the transport past its repository
    %%   view --> cfg    a widget re-reading a --dart-define instead of being handed the value

    %% `card` is reached WITHOUT a token: a client cannot present one before it
    %% has bootstrapped (ADR-B D-3, spec backend/0010 OD-1). Every other backend
    %% edge here carries the bearer token.

    %% `pres` is drawn inside the backend on purpose. It is the whole of ADR-K:
    %% the payload arriving at `repo` is ALREADY the widget's shape, with every
    %% number pre-formatted. Nothing between `repo` and `view` reshapes it — no
    %% mapper, no formatter, no computed field. That absence is the diagram's
    %% main claim.

    %% No node for routing: ADR-I D-1 keeps Navigator and declines go_router, so
    %% there are no URL routes, no deep links and no redirect layer to draw.
```

**Legend.** Solid = built and exercised today. Dashed + `(planned)` = not built:
Firebase auth is GGU-2, and the current `LoginBloc` simulates success.

**Two error shapes cross the `svc` boundary** and a repository must parse both
(ADR-J D-3): `/v1/**` answers RFC 9457 `application/problem+json`, while the
A2A root answers JSON-RPC **error objects with HTTP 200**. A failure before the
A2A envelope is parsed is a problem document on the A2A surface, so HTTP 200 is
not success there.

**The 220-line file budget and the layer directions above are review rules, not
checks.** The client gate (`dart.format`, `dart.analyze`, `client.tokens`,
`client.config`, `flutter.test`, `flutter.web`) lands with GGU-1 and enforces
formatting, analysis and the theme/config boundaries — not this diagram.
