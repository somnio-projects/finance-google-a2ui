# ADR-A — Session identity, ownership and isolation

- **Status:** Accepted (TL, 2026-09-18)
- **Gates:** GGU-46 (auth middleware), GGU-5 (portfolio in session state)
- **Evidence anchor:** `main` @ `410bb9d`

## Context

> **In the context of** an authenticated multi-user A2UI streaming service whose per-session state
> will hold a simulated portfolio, **facing** the fact that the ADK session key is today the
> client-supplied A2A `contextId` under a single hardcoded `user_id`, **we decided** to derive the
> ADK `user_id` from the verified Firebase `uid` and to treat `contextId` as a *within-user*
> conversation key only, **and neglected** (i) server-assigned opaque session ids and (ii) an
> out-of-ADK session store keyed by `(uid, sessionId)`, **to achieve** provable cross-user isolation
> and an honest acceptance criterion, **accepting that** every session lookup now requires the auth
> middleware to have run and published `uid` into the request scope, and that a client cannot resume
> a conversation across sign-outs.

### The defect this record exists to prevent

| Evidence | Fact |
|---|---|
| `backend_python/agent.py:70` | `self._user_id = "remote_agent"` — one constant for every caller |
| `backend_python/agent.py:218-229` | Sessions keyed by `(app_name, user_id, session_id)`; two are constants, so **`session_id` alone** is the key |
| `backend_python/agent_executor.py:174` | That `session_id` **is** the A2A `context_id` |
| `genui_a2a-0.10.1/.../a2ui_agent_connector.dart:40-41,150-152` | `contextId` is **supplied by the client** |

Token verification and session isolation are independent properties. A ticket can verify tokens,
pass its acceptance criteria, and still ship a backend where any authenticated caller presenting
another user's `contextId` reads and mutates that session.

Compounding: `agent.py:143-150` constructs a **fresh `InMemorySessionService()` on every
`_build_runner` call**, and it is called three times (text, v0.8, v0.9). There are three disjoint
session stores, not one — so an isolation test comparing two `session_id`s within one runner passes
while the bug is live.

## Decision

- **D-1** The ADK `user_id` MUST be the verified Firebase `uid`. The constant `"remote_agent"` is removed.
- **D-2** The A2A `contextId` is scoped **within** a `uid`. A request presenting a `contextId` that exists under a different `uid` MUST be treated as not-found (create a new session), never as a resume, and MUST NOT leak that the other session exists.
- **D-3** Exactly **one** `InMemorySessionService` instance serves all runners in the process. `_build_runner` receives it by injection rather than constructing one.
- **D-4** Session state is written **only** through ADK state-delta events. Direct mutation of `session.state` (as at `agent.py:230-231`) is prohibited.
- **D-5** Session state carries **no** cross-user data and no secrets: `base_url`, conversation scratch, and the portfolio (per ADR-F).
- **D-6** GGU-46 carries the acceptance criterion *"a session opened under uid A cannot be read or resumed by uid B, even when B presents A's contextId"* — proven by test, not by inspection.
- **D-7** Session lifetime is process lifetime. A backend restart loses all sessions; the client MUST tolerate an unknown `contextId` by starting a fresh session.

## Consequences

Session lookup is ordered after auth middleware. Conversation resume across sign-out is not
supported. The three-store fragmentation must be fixed as part of D-3 — it is not an optional
cleanup, because ADR-F places the portfolio in this state.
