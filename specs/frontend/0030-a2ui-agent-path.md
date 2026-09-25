# 0030 — The A2UI agent path: the client answers in interfaces

> **Renumbered from `0002` on 2026-09-24 by [`frontend/0029`](0029-the-conventions-are-checked.md)
> (GGU-105).** It shared `0002` with
> [`0002-chart-primitives-and-waterfall.md`](0002-chart-primitives-and-waterfall.md)
> from the day it merged, because both branches were cut from the same commit
> and each picked "the next free number" against its own branch point. This one
> moved rather than the other because every citation of it already named its
> slug, while twenty citations of `frontend/0002` — in nine Dart files, in
> `frontend/SECURITY.md` and in six sibling specs — are bare numbers that mean
> the chart spec. `0029` OD-2 carries the ruling; `repo.spec-numbers` now fails
> the build on a collision instead of leaving it for a directory listing.

- **Area:** frontend
- **Status:** Implemented
- **Ticket:** [GGU-79](https://somniosoftware.atlassian.net/browse/GGU-79) · **Related:** [`frontend/0001`](0001-frontend-skeleton.md) (GGU-91, the skeleton), [`client/0003`](../client/0003-client-backend-contract.md) (the normative contract), [`backend/0010`](../backend/0010-a2a-surface.md), [ADR-L](../../docs/adr/ADR-L-client-architecture.md), [ADR-D](../../docs/adr/ADR-D-a2ui-streaming-transport.md), [ADR-K](../../docs/adr/ADR-K-response-shaping.md)
- **Owner:** Lautaro Bertuzzi · **Date:** 2026-09-21

## 1. Problem

`frontend/` was a REST client. It fetched `/v1/…/views` and rendered them, and
it had **no agent path at all**: no A2A transport, no `message/stream`, no
handling of a render intent. The one thing this showcase exists to demonstrate
— an agent that answers by composing interface instead of prose — was the one
thing the client could not do.

Two defects on the path this work extends had to go first, because five more
components are about to be built on them:

- `app_router.dart` **hardcoded a view id**, and no test compared the router
  with the component registry. A component could be added, registered,
  100 %-covered and **invisible on screen with a green gate**.
- The read endpoint caps a request at four view ids, so registering a **fifth**
  component would have failed the whole surface.

## 2. Scope

**In**

- `A2aClient` + SSE decoding in `finance_api_client`.
- `AgentEvent` union, parser and `AgentRepository` in `finance_views_repository`.
- A conversation feature (bloc, page, view, transcript) and its route.
- Closing the router↔registry seam and the four-view cap.
- Widening the numbers rule to N-2/N-10 mechanisms, and narrowing the
  `SECURITY.md` claim to what is enforced.

**Out**

- **`genui` / `genui_a2a` / `a2ui_core`.** See OD-1 — they are not the right
  tool for this backend's wire contract, and no dependency could be added
  anyway (OD-2).
- Conversation history / `contextId` (GGU-46 owns sessions; omitting it is
  explicitly not an error, spec `client/0003` §8.2).
- Surface **actions** (`POST /` with a `data` part, spec `backend/0022`).
- Auth policy: the 401/403 branches remain `frontend/SECURITY.md` G-2.

## 3. API contract (consumed, not served)

| Call | Shape |
|---|---|
| `POST /` | JSON-RPC `message/stream`; `Authorization: Bearer`, `X-A2A-Extensions`, `Accept: text/event-stream` |
| answers | **three** shapes: 401 RFC 9457 problem · JSON-RPC error object at **HTTP 200** · SSE event stream |
| events | `status-update` → *n* × `render-intent` → `message` → terminal `status-update` → (on failure) `error` **after** `final: true` |
| then | each intent's payload is fetched with `GET /v1/portfolios/{id}/views?view=<id>` and the intent's own options |

## 4. Data model & migration

None. No generated DTOs (ADR-L D-4): a payload is still read by dotted path
through `ViewPayload`.

## 5. Security notes

- The credential is in the `Authorization` header and nowhere else — never a
  URL, query string or log line (**N-14**), asserted by a test.
- `http.ClientException.message` is never surfaced: on `BrowserClient` it
  carries the target URL. The client writes its own wording, as the REST
  transport already does.
- A failure shown to a user is the backend's own safe `code`/`message`.
- **HTTP 200 is never assumed to be success** on the A2A root (**N-12**).
- `jsonDecode` remains confined to the transport; `event_stream.dart` joins
  `finance_api_client.dart` in the `binding_rules_test.dart` allow list, with
  its reason written down (**N-5**).

## 6. Acceptance criteria

1. **AC-1** — `POST /` carries `Authorization` **and** `X-A2A-Extensions`; the token never reaches the URL. *(client/0003 AC-1, N-14)*
2. **AC-2** — All three answer shapes are parsed and each is a distinct failure. *(client/0003 AC-16, N-12)*
3. **AC-3** — The four event kinds are handled in order, and the stream is read **past** the terminal status so the trailing `error` is not lost. *(client/0003 AC-15)*
4. **AC-4** — `input_required` is a **success** terminal state. *(N-11, ADR-D D-3)*
5. **AC-5** — A surface is emitted **while the turn is still running**, before the answer text. *(ADR-K D-19)*
6. **AC-6** — A render intent resolves through the **same** `ComponentRegistry` and the same read endpoint a `?view=` request uses. No second rendering path.
7. **AC-7** — An unknown event kind, a malformed frame or an unregistered view degrades that one thing and never breaks the turn.
8. **AC-8** — Every registered component is reachable from the portfolio route; the router names no view id. *(the defect above)*
9. **AC-9** — More registered components than `maxViewsPerRequest` still resolve, in order, across several requests. *(the cap)*
10. **AC-10** — `tool/check_coverage.dart` fails on an empty source walk and applies its exemptions to the normalised path.
11. **AC-11** — N-2/N-10 mechanisms are checked, and `SECURITY.md` claims no more than is checked.
12. **AC-12** — `cd frontend && make gate` green.

## 7. Test plan

| AC | Tests |
|---|---|
| AC-1, AC-2 | `a2a_client_test.dart`, `a2a_client_failures_test.dart` |
| AC-3, AC-7 | `event_stream_test.dart`, `agent_event_parser_test.dart`, `agent_event_message_test.dart`, `agent_repository_test.dart` |
| AC-4 | `agent_event_parser_test.dart`, `conversation_bloc_test.dart` |
| AC-5, AC-6 | `agent_repository_test.dart::emits the surface before the answer`, `conversation_view_test.dart::answers in an interface, not only in text` |
| AC-7 | `conversation_surface_test.dart` (read failure, missing payload) |
| AC-8 | `app_router_test.dart::every registered component is reachable from the route` |
| AC-9 | `views_batch_test.dart`, `view_chunks_test.dart` |
| AC-10 | executed reproductions, before and after — see the PR body |
| AC-11 | `binding_rules_compute_test.dart` |

## 8. Open decisions

| # | Question | Owner | Resolution |
|---|---|---|---|
| **OD-1** | Should the client depend on `genui` / `genui_a2a` / `a2ui_core`, as `client_flutter/` does? | TL — **no, and this needs sign-off** | This backend does not stream A2UI component trees. `a2a_events.py::surface` emits `{"kind":"render-intent","renderIntent":{"view","options"}}`, and spec `client/0003` §8.3 states the intent "names a **registered** view; it never carries a payload. **The client fetches the payload itself**." The genui libraries render A2UI surface trees, of which this service sends none, so they would render nothing. Adding them would also import three alpha packages into the gate. **If the wire ever carries component trees, this decision is the one to revisit.** |
| **OD-2** | Could the decision have gone the other way on this machine? | — | **No.** Flutter is not installed and the standalone Dart is 3.12.1 against a `^3.13.0` floor, so the workspace does not resolve and **no dependency can be added at all** — `pubspec.lock` cannot be regenerated, and hand-editing it is forbidden (`frontend/CLAUDE.md`). The no-new-dependency design is also the only implementable one, which is a convergence worth recording rather than a justification. |
| **OD-3** | Does the client need `X-A2A-Extensions`? | TL — **send it, but the folklore is wrong** | Nothing under `backend/src/app/api/` or `services/` reads the header. The "omit it and A2UI silently degrades to a text agent" warning in the GGU-2/GGU-3 notes describes genui's `A2uiAgentConnector` against the upstream sample, **not** this stack. It is sent because `client/0003` AC-1 requires it and the protocol defines it. |
| **OD-4** | Should the conversation request surfaces for a portfolio other than `current`? | TL — **`current` for now** | `ConversationBloc.portfolioId` defaults to `current` and is injectable, so routing a portfolio id in later is a constructor argument, not a redesign. |
| **OD-5** | `tool/` has no tests of its own. | Lautaro — **carried, with a reason** | Adding `package:test` to the workspace root means a `dev_dependencies` entry, which changes `pubspec.lock` — impossible here (OD-2). The two bugs fixed in this spec were instead proven by **executing** the scripts against scratch trees, before and after. That is evidence, but it is not a suite, and the next person with a toolchain should add one. |
| **OD-6** | The live model path. | — | Per `client/0003` §8.6 a live turn may fail upstream. The client contract is unaffected — the event shapes are the contract — and a frontend developer must not "fix" it client-side. |
| **OD-7** | **GGU-69 AC-2 is only half met**, deliberately. It asks that ignoring the incremental events still yield a correct screen, and that **both** paths be asserted. | TL | `client/0003` §8.3 says the two ways to consume are both valid and to "**pick one and be consistent**". This client picks the incremental path, because AC-1 of the same ticket is time-to-first-widget. That the terminal `message` still repeats every intent **is** asserted, at the contract level (`agent_event_message_test.dart::reads the answer text and every surface of the turn`), so the fallback remains available. What is *not* built is a second rendering route that would re-fetch from `renderIntents` — it would risk rendering a surface twice, and a second path into one seam is the defect class ADR-K D-15 exists to prevent. Flagged rather than silently scoped out. |
