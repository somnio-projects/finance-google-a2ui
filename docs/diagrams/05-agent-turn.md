# 05 — An agent turn: question to streamed surfaces

How a sentence becomes UI. Source of truth: [ADR-D](../adr/ADR-D-a2ui-streaming-transport.md), [ADR-K](../adr/ADR-K-response-shaping.md), [spec 0006](../../specs/backend/0006-agent-host.md). Dashed = planned.

`AgentService.run_turn` (GGU-47) is everything between `turn(...)` and the
`TurnResult`. It is deliberately **synchronous and session-free**: it takes the
history as an argument, bounds itself to `AGENT_MAX_TOOL_ITERATIONS` model
calls, and returns the answer plus the render intents it collected. The A2A
adapter (GGU-3) is what turns that into a stream; `SessionService` (GGU-46) is
what supplies and persists the history.

```mermaid
sequenceDiagram
    autonumber
    participant C as Flutter client
    participant A as A2A adapter (root)
    participant S as SessionService
    participant H as AgentService (GGU-47)
    participant M as ModelClient (Gemini · Null)
    participant T as Tool registry
    participant P as Projection registry
    participant DB as PostgreSQL

    C-->>A: message/stream + Bearer + contextId
    A-->>A: resolve contextId AGAINST the verified subject
    A-->>S: load conversation (subject-scoped)
    S-->>DB: sessions + messages
    A-->>H: run_turn(prompt, history, ToolContext)

    loop up to AGENT_MAX_TOOL_ITERATIONS model calls
        H->>M: system prompt + history + tool schemas
        M->>H: text, or tool call(s)
        H->>T: run tool (pure, Decimal, injected clock)
        T->>H: ToolOutcome: *Display strings (+ render intent, if one fits)
        H->>M: tool results fed back
    end
    H-->>A: TurnResult {message, render_intents, counters}

    H-->>P: validate intent against the registry (GGU-49)
    P-->>H: rejected → default projection (recorded in telemetry)
    A-->>C: stream surface #1, #2 …
    A-->>S: append assistant message
    S-->>DB: persist

    %% Solid = shipped in GGU-47. Dashed = the surrounding tickets.
    %% A turn emits exactly one agent.turn metric and one log line:
    %% model, outcome, duration, counters — never prompt, result or subject.
    %% An unknown or raising tool becomes {"error": "tool-failed"} fed back, not a
    %% failed turn — the message is dropped, because it can quote a holding. A
    %% tool with something useful to say about a refusal returns its own
    %% {"error": ...} payload instead of raising (spec 0013 OD-3).
    %% A tool emits a render intent only when a registered projection actually
    %% fits the answer it just produced: a filtered or re-ordered result whose
    %% chart would contradict it carries none (spec 0011 OD-1).
    %% The model picks a view; it never invents a shape or a number.
```
