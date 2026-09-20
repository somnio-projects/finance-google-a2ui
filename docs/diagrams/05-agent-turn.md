# 05 — An agent turn: question to streamed surfaces

How a sentence becomes UI. Source of truth: [ADR-D](../adr/ADR-D-a2ui-streaming-transport.md), [ADR-K](../adr/ADR-K-response-shaping.md), [spec 0006](../../specs/backend/0006-agent-host.md), [spec 0012](../../specs/backend/0012-delivery-followups.md). Dashed = planned.

The turn is everything between `run_turn_events(...)` and `TurnCompleted`. It
is **session-free**: it takes the history as an argument, bounds itself to
`AGENT_MAX_TOOL_ITERATIONS` model calls, and holds no state between turns.

What changed with spec 0012 is *when* it speaks. `AgentService.run_turn_events`
(over `TurnLoop`, `services/agent_loop.py`) is an async generator: each render
intent leaves the loop as a `SurfaceReady` the moment the tool that produced it
returned, and the A2A adapter forwards it as a `render-intent` event while the
model is still talking (ADR-K D-19). `run_turn` remains as a thin collector for
callers that want the finished value. `SessionService` (GGU-46) — which would
supply and persist the history, and resolve `contextId` against the verified
subject — is **not on this branch**: every turn starts empty (spec 0012 OD-3).
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
    participant S as SessionService (planned)
    participant H as AgentService
    participant L as TurnLoop
    participant S as SessionService
    participant H as AgentService (GGU-47)
    participant M as ModelClient (Gemini · Null)
    participant T as Tool registry
    participant P as Projection registry

    C->>A: message/stream + Bearer + contextId
    A-->>S: resolve contextId AGAINST the verified subject, load history
    S-->>A: (planned — GGU-46; today history = [])
    A->>H: run_turn_events(prompt, history, ToolContext)
    A->>C: status-update{working}
    H->>L: run(messages, context, state)

    loop up to AGENT_MAX_TOOL_ITERATIONS model calls
        L->>M: system prompt + history + tool schemas
        M->>L: text, or tool call(s)
        L->>T: run tool (pure, Decimal, injected clock)
        T->>L: ToolOutcome: *Display strings + render intent
        L->>H: SurfaceReady{index, intent}
        H->>A: (yielded, mid-turn)
        A->>C: render-intent #0, #1 … as each is ready
        L->>M: tool results fed back
    end

    L->>H: TurnCompleted{message, render_intents, counters}
    A->>C: message (answer + every renderIntent)
    A->>C: status-update{completed | input_required}
    H-->>P: the client resolves each intent against the registry (GGU-49)
    A-->>S: append assistant message (planned — GGU-46)

    %% Solid = shipped. Dashed = the session work this branch does not carry.
    %% The `message` event repeats every intent on purpose: a client that
    %% ignores `render-intent` still sees the full list (spec 0010 AC-2).
    %% A turn emits exactly one agent.turn metric and one log line:
    %% model, outcome, duration, counters — never prompt, result or subject.
    %% The incremental events add NO log line: the shape of a conversation
    %% is the user's, and a per-surface log would put it in the logs.
    %% An unknown or raising tool becomes {"error": ...} fed back, not a failed turn.
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
        T->>H: ToolOutcome: *Display strings + render intent
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
    %% An unknown or raising tool becomes {"error": ...} fed back, not a failed turn.
    %% A tool emits a render intent only when a registered projection actually
    %% fits the answer it just produced: a filtered or re-ordered result whose
    %% chart would contradict it carries none (spec 0011 OD-1), and a tool no
    %% projection draws at all — payoff (spec 0014 OD-7) — returns figures
    %% only, so the turn answers in text rather than aiming an ill-fitting
    %% chart at a correct sentence.
    %% An unknown or raising tool becomes {"error": "tool-failed"} fed back, not a
    %% failed turn — the message is dropped, because it can quote a holding. A
    %% tool with something useful to say about a refusal returns its own
    %% {"error": ...} payload instead of raising (spec 0013 OD-3).
    %% An unknown or raising tool becomes {"error": ...} fed back, not a failed turn.
    %% A tool emits a render intent only when a registered projection actually
    %% fits the answer it just produced: a filtered or re-ordered result whose
    %% chart would contradict it carries none (spec 0011 OD-1).
    %% The model picks a view; it never invents a shape or a number.
```
