# 05 — An agent turn: question to streamed surfaces

How a sentence becomes UI. Source of truth: [ADR-D](../adr/ADR-D-a2ui-streaming-transport.md), [ADR-K](../adr/ADR-K-response-shaping.md), GGU-47. Dashed = planned.

```mermaid
sequenceDiagram
    autonumber
    participant C as Flutter client
    participant A as A2A adapter (root)
    participant S as SessionService
    participant H as AgentHost (GGU-47)
    participant M as Gemini
    participant T as Deterministic tools
    participant P as Projection registry
    participant DB as PostgreSQL

    C->>A: message/stream + Bearer + contextId
    A->>A: resolve contextId AGAINST the verified subject
    A->>S: load conversation (subject-scoped)
    S->>DB: sessions + messages
    A->>H: turn(history, question)
    H->>M: system prompt (catalog fragments) + history + tool schemas
    M-->>H: tool call(s) + render intent {view, options}
    H->>T: execute tool (pure, Decimal, injected clock)
    T-->>H: result with *Display strings
    H->>P: validate intent against the registry
    P-->>H: rejected → default projection (recorded in telemetry)
    P-->>H: payload for the chosen view
    H-->>A: surface ready
    A-->>C: stream surface #1
    H->>M: continue turn
    A-->>C: stream surface #2 …
    H->>S: append assistant message
    S->>DB: persist

    %% First pixel is the time to surface #1, not to the last one.
    %% The model picks a view; it never invents a shape or a number.
```
