# 0019 — The turn always ends

- **Area:** frontend (the A2A repository and the conversation bloc)
- **Status:** In progress
- **Ticket:** _unassigned — no GGU number exists for this yet; none is invented here_
- **Also:** [backend/0036](../backend/0036-the-turn-is-fast-honest-and-observable.md) (the server half), [frontend/0011](0011-the-assistant-as-designed.md) (the Assistant), [ADR-L](../../docs/adr/ADR-L-client-architecture.md) D-8 (errors are values), [`specs/client/0003`](../client/0003-client-backend-contract.md) N-14
- **Owner:** Lautaro Bertuzzi · **Date:** 2026-09-22

## 1. Problem

Reported as: *"a veces el assistente crashea y no deja contestarle... después
de un tiempo queda ahí idle."* The typing indicator keeps animating, the send
button stays grey, and the only way out is a reload.

`AgentRepository`'s class docstring says:

> **Every failure is an event, not a thrown exception**, because a turn can
> fail after it has already produced surfaces … Nothing throws across this
> boundary (ADR-L D-8).

That was false for exactly the case it names. `A2aClient.startTurn` guards
`send()` and the response's interpretation, but once it returns
`Ok(decodeEventStream(...))`, an error raised **on** those bytes — a reset
connection, an SSE the edge closed, a read timeout after the headers arrived
— is rethrown by `_events`'s `await for`, travels through
`ConversationBloc._run`'s own `await for`, and leaves the event handler as an
exception. Bloc hands it to `onError` and **leaves the state untouched**, so
`ConversationStatus.running` is where the screen stays.

The bloc already reasoned about this — *"showing what arrived beats leaving
the surface spinning forever"* — but only for a stream that **ended**, not for
one that threw.

## 2. Rulings

- **OD-1 — a failure on the stream is an event, like every other failure.**
  `_events` catches and yields `AgentFailed`. The message is **ours**
  (`'the agent stopped answering'`) and fixed: at that point the backend has
  said nothing, and an exception's text on `BrowserClient` carries the target
  URL (N-14). The code is the existing `transport-unavailable` — a failure the
  UI already knows how to render, so this adds no new branch above.

- **OD-2 — `on Object`, not a narrower clause.** What arrives is whatever the
  transport chose to raise, and it differs between web and VM. A clause narrow
  enough to miss one of them restores the hang for that one. There is no
  failure on this stream that should reach the UI as an exception.

- **OD-3 — the bloc leaves `running` in a `finally`, unconditionally.**
  With OD-1 nothing *should* escape — and "should" is precisely what the
  status was trusting before. The cost of being wrong is the whole screen, and
  there is no state of the world in which a finished turn should still look
  like it is running. Two locks, deliberately.

- **OD-4 — the bloc's suite is not `blocTest`, and that is the finding worth
  keeping.** Written with `blocTest` and an `errors:` matcher, this suite
  **passed with the fix reverted**: the handler's exception ends `act`, so
  `verify` — where the only assertion lived — never ran. It was caught by
  mutating the bloc and watching the suite stay green, which is the repository's
  standing rule (*a green check is evidence only if it could have been red*).
  It is now a plain `test()` with the assertion on the main path.

  A second trap sat underneath it: the bloc must be **constructed inside**
  `runZonedGuarded`, because Bloc's event subscription runs in the zone where
  the bloc was created. Built outside, its unhandled error goes to the test
  framework's zone and the suite fails for the wrong reason.

## 3. Acceptance criteria

1. **AC-1** — an error raised on the turn's stream yields an `AgentFailed` event instead of throwing.
2. **AC-2** — events that arrived before the failure are still delivered.
3. **AC-3** — the failure's message is the fixed sentence and never the transport's text.
4. **AC-4** — a raised object that is not an `Exception` is handled the same way.
5. **AC-5** — when something does escape the turn, the bloc still comes to rest at `ConversationStatus.idle`, with the echoed user turn intact.
6. **AC-6** — `cd frontend && make gate` green, 100 % line coverage per file.

## 4. Test plan

| AC | How |
|---|---|
| 1–4 | `agent_repository_stream_error_test.dart` — a `MockClient.streaming` body that emits frames and then `addError`, which is the real shape: `A2aClient` has already returned `Ok(stream)` by then |
| 5 | `conversation_escape_test.dart` — a turn stream that raises, driven inside `runZonedGuarded`, asserting the resting state |
| all | **mutation-checked**: with each half reverted, the corresponding suite goes red |

## 5. Out of scope

- Retrying a dropped turn. The user sees what arrived and a failure, and can ask again; an automatic retry would re-run tool calls whose effects the reader has already been shown.
- Any change to what `ConversationStatus.idle` renders — `assistant_frame_test.dart` already covers the failure state.
