# 05 — An agent turn: question to streamed surfaces

How a sentence — or a tap — becomes UI. Source of truth: [ADR-D](../adr/ADR-D-a2ui-streaming-transport.md), [ADR-J](../adr/ADR-J-rest-api-and-a2a-surface.md) D-7, [ADR-K](../adr/ADR-K-response-shaping.md), [spec 0006](../../specs/backend/0006-agent-host.md), [spec 0012](../../specs/backend/0012-delivery-followups.md), [spec 0022](../../specs/backend/0022-surface-actions.md). Dashed = planned. The v1.0 route (`/a2ui/v1/a2a`) runs this same turn and differs only in how a validated intent becomes bytes — diagram [14](14-a2ui-v1-wire.md).

The turn is everything between `run_turn_events(...)` and `TurnCompleted`. It
is **session-free**: it takes the history as an argument, bounds itself to
`AGENT_MAX_TOOL_ITERATIONS` model calls, and holds no state between turns.

What changed with spec 0012 is *when* it speaks. `AgentService.run_turn_events`
(over `TurnLoop`, `services/agent_loop.py`) is an async generator: each render
intent leaves the loop as a `SurfaceReady` the moment the tool that produced it
returned, and the A2A adapter forwards it as a `render-intent` event while the
model is still talking (ADR-K D-19). `run_turn` remains as a thin collector for
callers that want the finished value.

What changed with GGU-84 is *what may leave it*. A tool's render intent is
judged against the projection registry — the view id **and** its options,
through `RenderIntentService` — before it is appended to the turn, so both
exits (the streamed surface and the final `TurnResult`) carry a view the
registry accepted. A refused choice is recorded and replaced by the endpoint's
default projection; it never fails the turn (ADR-K D-12).

What changed with spec 0022 is *who may start one*. A message carries either
prose or **one `data` part** naming a registered action; the action is resolved
and its arguments validated **before the stream opens**, and the prompt the
turn receives is composed in backend code (ADR-J D-7).

`SessionService` (GGU-46) — which would supply and persist the history, and
resolve `contextId` against the verified subject — is **not on this branch**:
every turn starts empty (spec 0012 OD-3).

```mermaid
sequenceDiagram
    autonumber
    participant C as Flutter client
    participant A as A2A adapter (root)
    participant X as SurfaceActionService
    participant S as SessionService (planned)
    participant H as AgentService
    participant L as TurnLoop
    participant M as ModelClient (Gemini · Scripted · Null)
    participant T as Tool registry
    participant P as Projection registry

    C->>A: message/stream + Bearer + contextId
    A-->>S: resolve contextId AGAINST the verified subject, load history
    S-->>A: (planned — GGU-46; today history = [])

    alt message carries a data part (a tap)
        A->>X: prompt_for(principal, {action, args})
        X->>X: flag surface.actions · registry lookup · bounded args
        X-->>A: refused → JSON-RPC error at HTTP 200, stream never opens
        X->>A: accepted → the prompt the BACKEND composed
    else message carries text (a sentence)
        A->>A: prompt = the text parts, joined
    end

    A->>H: run_turn_events(prompt, history, ToolContext)
    A->>C: status-update{working}
    H->>L: run(messages, context, state)

    loop up to AGENT_MAX_TOOL_ITERATIONS model calls
        L->>M: system prompt + history + tool schemas
        M->>L: text, or tool call(s)
        L->>T: run tool (pure, Decimal, injected clock)
        T->>L: ToolOutcome: *Display strings + render intent
        L->>P: accept(view, options)?
        P->>L: the same intent, or the default + REJECTED_METRIC
        L->>H: SurfaceReady{index, intent}
        H->>A: (yielded, mid-turn)
        A->>C: render-intent #0, #1 … as each is ready
        L->>M: tool results fed back
    end

    L->>H: TurnCompleted{message, render_intents, counters}
    A->>C: message (answer + every renderIntent + suggestions)
    A->>C: status-update{completed | input_required}
    A-->>S: append assistant message (planned — GGU-46)

    %% Solid = shipped. Dashed = the session work this branch does not carry.
    %% The registry step is the whole of GGU-84: until it existed, a tool-emitted
    %% view id met only VIEW_ID_SHAPE — a regex `totally.invented.v9` satisfies —
    %% and options were never judged at all. The call lives in agent_tools, the
    %% one place an intent enters a turn, so it covers both ways one leaves.
    %% A rejection NEVER fails the turn (ADR-K D-12): the default projection is
    %% substituted, the metric is recorded, the conversation still shows a chart.
    %% The `message` event repeats every intent on purpose: a client that
    %% ignores `render-intent` still sees the full list (spec 0010 AC-2).
    %% `suggestions` are the curated chips the client may tap next (spec 0029):
    %% keys with labels, chosen by the adapter from the table minus the prompt
    %% just run — never by the model, which cannot invent a chip (0022 OD-1).
    %% A tapped chip or bar comes back as the data part at the top.
    %% A turn emits exactly one agent.turn metric and one log line:
    %% model, outcome, duration, counters — never prompt, result or subject.
    %% The incremental events add NO log line: the shape of a conversation
    %% is the user's, and a per-surface log would put it in the logs.
    %% An unknown or raising tool becomes {"error": ...} fed back, not a failed
    %% turn — the message is dropped, because it can quote a holding. A tool
    %% with something useful to say about a refusal returns its own
    %% {"error": ...} payload instead of raising (spec 0013 OD-3).
    %% A tool emits a render intent only when a registered projection actually
    %% fits the answer it just produced: a filtered or re-ordered result whose
    %% chart would contradict it carries none (spec 0011 OD-1), and a tool no
    %% projection draws at all — payoff (spec 0014 OD-7) — returns figures
    %% only, so the turn answers in text rather than aiming an ill-fitting
    %% chart at a correct sentence.
    %% The model picks a view; it never invents a shape or a number.
    %% M is chosen once, in infra/model/factory.py: a configured GEMINI_API_KEY
    %% is Gemini; no key is the SCRIPTED client (spec 0033), which replays the
    %% demo's flows from a table — the design's three questions, the four
    %% curated chips and the drill — as tool calls first and a server-written
    %% sentence second, its figures copied from the results fed back. A prompt
    %% outside the table gets the null client's "no model provider" sentence.
    %% There is no mixed mode (0033 OD-4). Null itself is now the test double.
    %% The "tool schemas" on the call to M are not the schemas the tools
    %% publish: infra/model/tool_schema.py translates them into the subset
    %% Gemini's `parameters` field parses (GGU-81) — $refs resolved, refused
    %% keywords dropped. The tools' own declarations are untouched, so the
    %% OpenAPI document and the argument-bounds gate still read the full ones.
    %% "tool results fed back" is the edge that was broken until GGU-90/GGU-88,
    %% and it carries two provider facts the reader would otherwise get wrong:
    %%   1. a functionResponse part travels under role "user", NOT "function" —
    %%      Gemini has no tool role at all (infra/model/wire_roles.py);
    %%   2. the assistant turn re-sent above it must echo, verbatim, the
    %%      thoughtSignature Gemini attached to each functionCall, carried as
    %%      ToolCall.provider_state (infra/model/reply.py). Dropping either is
    %%      a 400 on the SECOND call — after the tool has run and its surface
    %%      has already been streamed, so the client sees a render-intent and
    %%      then a failure. The loop and the event order are unchanged.
    %% A provider rejection is masked outward as dependency-unavailable AND
    %% logged inward at warning with the provider's own text (GGU-90 AC-4).
    %% An ACTION is resolved before `status-update{working}` is emitted, which
    %% is the whole reason it is a clean JSON-RPC error rather than a stream
    %% that fails on its first event (spec 0022 AC-4). Rejection is terminal:
    %% unlike an invalid render intent there is no default to fall back to.
    %% The client sends an id and scalars; the sentence, the tool and the view
    %% all come from backend code (ADR-K D-3, ADR-J D-7).
```
