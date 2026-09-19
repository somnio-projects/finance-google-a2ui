# 0004 — Session identity: conversation sessions bound to the verified subject

- **Area:** backend
- **Status:** Draft — implemented in the same PR (GGU-46); approve or amend at review
- **Ticket:** GGU-46 · **Related specs / ADRs:** 0001, 0002, [ADR-A](../../docs/adr/ADR-A-session-identity.md), [ADR-F](../../docs/adr/ADR-F-persistence-and-session-lifetime.md)
- **Owner:** Lautaro Bertuzzi · **Date:** 2026-09-19

## 1. Problem

GGU-46 was written against the deleted ADK sample (`backend_python/agent.py`,
`InMemorySessionService`, the client-supplied A2A `contextId` as the session
key). That code no longer exists, and the property the ticket exists to
protect — ADR-A D-6, *"a session opened under uid A cannot be read or resumed
by uid B"* — has no home in the current backend.

Token verification is already done: `auth/providers/{jwt,oidc}_provider.py`
verify signature, `iss`, `aud`, `exp`, `iat` and require `sub`;
`api/deps.py::get_current_principal` puts a typed `Principal` on every route;
rate limiting and the `audit_events` trail are in place (spec 0001, 0002).
**What is missing is the resource the isolation claim is about:** the backend
has no sessions at all. ADR-A is explicit that verification and isolation are
independent properties — a service can verify every token perfectly and still
let any authenticated caller read another subject's conversation.

This spec therefore re-baselines GGU-46 as: *persisted conversation sessions
owned by the verified subject, with cross-subject isolation proven by test.*

## 2. Scope

**In:** a `sessions` table and a `messages` table; a `SessionRepository` whose
every query is scoped by subject; a `SessionService` that resolves ownership
before any read or mutation and answers `NotFoundError` (never
`AuthorizationError`) for a session that belongs to somebody else; a RESTful
`/v1/sessions` surface (create, list, read, delete, append message, read
conversation) with cursor pagination; audit events for every session action;
the whole surface behind the `sessions.api` feature flag.

**Out:** the A2UI agent turn loop and A2A `contextId` mapping (ADR-J and the
agent tickets — this spec owns the store, not the protocol adapter); the
simulated portfolio in session state (GGU-5, ADR-F D-2/D-3); session sharing
between subjects; editing or deleting an individual message; server-side
retention/expiry of sessions (see OD-2); full-text search over conversations.

ADR-F D-1 ("no durable persistence in Epic 0") described the ADK sample's
in-memory services. It is **not** contradicted operationally by this spec: the
backend already owns a PostgreSQL instance and an Alembic pipeline (spec 0001),
and ADR-F D-3 exists precisely so that moving conversation state into a durable
store is a contained change. Recorded as OD-1 for the TL to confirm.

## 3. API contract

All routes require `Authorization: Bearer <token>` and sit behind
`require_feature("sessions.api", default=True)`; while the flag is off every
route answers `feature-disabled → 404`. `{session_id}` is a UUID.

| Method & path | Auth | Request | Response | Errors (code → status) |
|---|---|---|---|---|
| `POST /v1/sessions` | Bearer | `SessionCreate{title?}` | `201` `SessionResponse` + `Location: /v1/sessions/{id}`; audited `session.create` | `validation-failed → 422`, `auth/* → 401`, `rate-limited → 429`, `dependency-unavailable → 503` |
| `GET /v1/sessions` | Bearer | `?limit=1..100&cursor=<opaque>` | `200` `SessionPage{items, next_cursor}`, newest first; audited `session.list` | `validation-failed → 422` (bad cursor or limit), `401`, `429`, `503` |
| `GET /v1/sessions/{session_id}` | Bearer | — | `200` `SessionResponse`; audited `session.read` | `not-found → 404` (unknown **or** another subject's), `401`, `422`, `429`, `503` |
| `DELETE /v1/sessions/{session_id}` | Bearer | — | `204` no body; audited `session.delete` | `not-found → 404`, `401`, `422`, `429`, `503` |
| `POST /v1/sessions/{session_id}/messages` | Bearer | `MessageCreate{role, content}` | `201` `MessageResponse`; audited `session.append` | `not-found → 404`, `validation-failed → 422`, `401`, `429`, `503` |
| `GET /v1/sessions/{session_id}/messages` | Bearer | `?limit=1..100&cursor=<opaque>` | `200` `MessagePage{items, next_cursor}`, **oldest first (newest last)**; audited `session.read` | `not-found → 404`, `422`, `401`, `429`, `503` |

DTOs (`ConfigDict(frozen=True)`, every field documented, bounded and
exemplified — `.claude/rules/backend/api-design.md` §2):

- `SessionCreate{title: str | None, max_length=200}` — the owner is **never**
  in the body; it is `principal.subject`.
- `SessionResponse{id: UUID, title: str | None, created_at, updated_at}` —
  `subject` is deliberately **not** exposed: the caller is the owner by
  construction, and echoing the identifier adds nothing but a leak surface.
- `MessageCreate{role: "user"|"assistant"|"system", content: str, 1..8000}`.
- `MessageResponse{id, session_id, role, content, created_at}`.
- `SessionPage`/`MessagePage` both extend `Page[ItemT]{items, next_cursor}`
  (`schemas/pagination.py`) so the pagination envelope exists once.

Pagination is **keyset**, not offset: `cursor` is an opaque, URL-safe base64
of `(created_at, id)` of the last item of the previous page
(`helpers/cursor.py`). A cursor that does not decode is `validation-failed →
422`; it is never interpreted as "start from the beginning". `next_cursor` is
`null` on the last page. Rationale: an offset skips or repeats rows while a
conversation grows, and a keyset cursor over `(created_at, id)` matches the
indexes below exactly.

Problem-details codes follow `https://errors.finance-a2ui/<code>`.

## 4. Data model & migration

Alembic revision **`0004`** (`20260919_0004_sessions.py`, revises `0003`).
No existing rows are affected — both tables are new.

```
sessions(
  id           uuid          primary key,
  subject      varchar(255)  not null,   -- the verified `sub`, the ownership key
  provider     varchar(32)   not null,   -- which verifier issued it (jwt | oidc)
  title        varchar(200)  null,
  created_at   timestamptz   not null default now(),
  updated_at   timestamptz   not null default now()   -- bumped on append
)
index ix_sessions_subject_created on (subject, created_at)

messages(
  id           uuid          primary key,
  session_id   uuid          not null references sessions(id) on delete cascade,
  role         varchar(16)   not null check (role in ('user','assistant','system')),
  content      text          not null,
  created_at   timestamptz   not null default now()
)
index ix_messages_session_created on (session_id, created_at)
```

`ix_sessions_subject_created` is the index the isolation filter uses: every
session query carries `subject = :subject`, so the subject is the **leading**
column — an index on `created_at` alone would make the scoped query a scan and
invite somebody to "optimise" the filter away. `ix_messages_session_created`
serves the conversation read in `(session_id, created_at)` order.

`ON DELETE CASCADE` is declared in the database, not emulated in Python: a
deleted session must not be able to leave orphan messages behind, whatever
code path removed it. `role` is constrained by a CHECK constraint
(`ck_messages_role_allowed`) as well as by the pydantic `Literal`, because the
database is the last line of defence and migrations are the only schema path.

`alembic check` reports no drift between `models/` and revision `0004`.

## 5. Security notes

This is the highest-stakes property in the epic. It is **not** a consequence of
token verification (ADR-A: the two are independent), so it is enforced in one
place and proven by a mutation check.

- **Ownership is never taken from the request.** The owner of a session is
  `principal.subject` from the verified token. No path, query or body field can
  name another subject.
- **Every repository query is scoped by subject.** `get_for_subject`,
  `list_for_subject` and `delete_for_subject` all carry
  `sessions.subject = :subject` in the `WHERE` clause; there is no unscoped
  read of a session in `SessionService`. Message queries are reachable only
  after the parent session has been resolved for the caller.
- **A foreign session is `404 not-found`, never `403 forbidden`.** A 403 would
  confirm that the id exists; the two cases (unknown id, somebody else's id)
  are indistinguishable to the caller: same status, `type` and `title`, and a `detail` (`session <id> not found`) that only repeats the id the caller sent.
- **`DELETE` on a foreign session answers 404 and changes nothing.** The
  isolation test asserts the owner can still read the session afterwards.
- **Audit trail** (SOC 2 CC7.2 / ISO A.8.15, via `AuditService.record` with
  `target=<session id>`): `session.create`, `session.read`, `session.list`,
  `session.append`, `session.delete`. Each row carries the actor's subject,
  provider, token fingerprint and request id — never the token, never the
  message content.
- **Personal data.** `messages.content` is free text supplied by the caller and
  must be treated as personal data: it is never logged, never echoed in a
  problem detail, and bounded to 8 000 characters (`max_request_body_bytes`
  still applies on top). Deleting a session is the subject's erasure path and
  cascades to its messages. Retention beyond that is OD-2.
- **Feature flag.** The whole surface is behind `sessions.api` (default
  enabled); the gate answers 404 before the route body, so the endpoints can be
  switched off without a deploy (spec 0002).
- **Availability.** Database failures surface as `503 dependency-unavailable`
  through `DependencyUnavailableError`; no SQLAlchemy text ever reaches the
  caller.

## 6. Acceptance criteria

1. **AC-1** `POST /v1/sessions` answers `201` with `Location: /v1/sessions/{id}` and a `SessionResponse`; the stored row carries `subject = principal.subject` and `provider = principal.provider`, and an `audit_events` row `action=session.create, target=<id>` is written. A body that tries to name an owner cannot change it (no such field exists).
2. **AC-2** `GET /v1/sessions` returns **only** the caller's sessions, newest first, `limit` bounded to 1..100 (default 20). With more rows than `limit` the response carries a `next_cursor` that returns the following page and never repeats or skips a row; the last page has `next_cursor = null`. The read is audited as `session.list`.
3. **AC-3** `GET /v1/sessions/{id}` returns the caller's session and audits `session.read` with `target=<id>`. For a session owned by another subject — and for an unknown id — it answers `404` with `type` ending in `/not-found`; the two answers are indistinguishable — same status, `type` and `title`, and a `detail` that differs only by the id the caller itself supplied — and neither ever says the session exists.
4. **AC-4** `DELETE /v1/sessions/{id}` on the caller's own session answers `204`, removes the row and cascades to its messages, and audits `session.delete`. Repeating it answers `404` and changes nothing further (no additional effect — the delete is idempotent on server state). `DELETE` of another subject's session answers `404` **and leaves that session readable by its owner**.
5. **AC-5** `POST /v1/sessions/{id}/messages` appends a message with `role ∈ {user, assistant, system}` and answers `201` with the `MessageResponse`, audited as `session.append` with `target=<id>`. Another subject's session answers `404`. An unknown role, an empty `content` or one over 8 000 characters answers `422`.
6. **AC-6** `GET /v1/sessions/{id}/messages` returns the conversation **oldest first (newest last)**, paginated with the same `limit`/`cursor` contract as AC-2, audited as `session.read`. Another subject's session answers `404`.
7. **AC-7** Every route requires a bearer token (`401` without one) and is gated by `sessions.api`: with the flag off, every route answers `404 feature-disabled`, including for a session id that exists.
8. **AC-8** A `cursor` that is not a valid cursor answers `422 validation-failed` on both paginated routes; it is never silently treated as "no cursor".
9. **AC-9** A database failure inside any session query surfaces as `503 dependency-unavailable` (RFC 9457) with no SQLAlchemy text in the body, through `DependencyUnavailableError` raised in the repository.
10. **AC-10** The OpenAPI document carries, for all six operations, `operation_id`, `summary`, a real `description`, the `sessions` tag, `response_model`, the full `responses` map and described, bounded parameters and schema fields; `make gate` is green (ruff, basedpyright strict, ≤150 lines per file, `make quality`, 100 % branch coverage, pip-audit) and `alembic check` reports no drift.

## 7. Test plan

| AC | Unit test(s) | Integration test(s) |
|---|---|---|
| AC-1 | `tests/unit/services/test_session_service.py::test_create_persists_owner_from_principal_and_audits`, `tests/unit/api/test_sessions_api.py::test_create_answers_201_with_a_location_header` | `tests/integration/test_session_flow.py::test_create_returns_location_and_round_trips` |
| AC-2 | `tests/unit/services/test_session_service.py::test_list_sessions_pages_with_cursor_and_scopes_by_subject` | `tests/integration/test_session_flow.py::test_session_listing_pages_newest_first` |
| AC-3 | `tests/unit/services/test_session_service.py::test_reads_of_another_subject_raise_not_found`, `::test_get_returns_the_callers_own_session_and_audits` | `tests/integration/test_session_isolation.py::test_other_subject_gets_404_on_read`, `::test_listing_never_shows_another_subjects_session`, `tests/integration/test_session_repository.py::test_create_and_get_are_scoped_to_the_owning_subject` |
| AC-4 | `tests/unit/services/test_session_service.py::test_delete_removes_own_session_and_audits`, `::test_delete_of_another_subject_raises_not_found` | `tests/integration/test_session_flow.py::test_delete_is_204_then_404_and_cascades_messages`, `tests/integration/test_session_isolation.py::test_other_subject_gets_404_on_delete_and_leaves_the_session_intact`, `tests/integration/test_session_repository.py::test_delete_is_scoped_and_cascades_to_messages` |
| AC-5 | `tests/unit/services/test_session_messages_service.py::test_append_message_audits_with_target`, `tests/unit/services/test_session_service.py::test_reads_of_another_subject_raise_not_found`, `tests/unit/api/test_sessions_api_validation.py::test_invalid_message_bodies_are_422` | `tests/integration/test_session_messages_flow.py::test_messages_round_trip_oldest_first`, `::test_invalid_message_is_422`, `tests/integration/test_session_isolation.py::test_other_subject_gets_404_on_message_append` |
| AC-6 | `tests/unit/services/test_session_messages_service.py::test_list_messages_pages_oldest_first` | `tests/integration/test_session_messages_flow.py::test_message_listing_pages_oldest_first`, `tests/integration/test_session_isolation.py::test_other_subject_gets_404_on_reading_the_conversation` |
| AC-7 | `tests/unit/api/test_sessions_api.py::test_routes_require_a_bearer_token`, `::test_routes_are_404_while_the_flag_is_off` (both over all six routes) | `tests/integration/test_session_flow.py::test_flag_off_hides_every_session_route` |
| AC-8 | `tests/unit/helpers/test_cursor.py::test_decode_rejects_a_garbled_cursor`, `tests/unit/api/test_sessions_api_validation.py::test_invalid_cursor_is_422_before_the_database`, `tests/unit/services/test_session_service.py::test_an_unusable_cursor_is_rejected_before_the_repository` | `tests/integration/test_session_flow.py::test_invalid_cursor_is_422` |
| AC-9 | `tests/unit/api/test_sessions_api.py::test_database_failure_is_503` | `tests/integration/test_session_repository.py::test_infrastructure_errors_are_translated` |
| AC-10 | `tests/unit/api/test_openapi_contract.py` (every operation, parameter and schema field) | `make gate` |

Mutation checks required (auth / isolation / error masking): **yes**, and
performed 2026-09-19 against the real PostgreSQL:

| Mutation | Result |
|---|---|
| `ConversationSession.subject == subject` removed from `SessionRepository.get_for_subject` | **red** — `test_session_isolation.py::test_other_subject_gets_404_on_read`, `::test_other_subject_gets_404_on_message_append`, `::test_other_subject_gets_404_on_reading_the_conversation` and `test_session_repository.py::test_create_and_get_are_scoped_to_the_owning_subject` fail (4 failed, 5 passed) |
| `ConversationSession.subject == subject` removed from `SessionRepository.delete_for_subject` | **red** — `test_session_isolation.py::test_other_subject_gets_404_on_delete_and_leaves_the_session_intact` and `test_session_repository.py::test_delete_is_scoped_and_cascades_to_messages` fail (2 failed, 7 passed) |
| both filters restored | green — 9 passed |

## 8. Open decisions

| # | Question | Owner | Default if unresolved |
|---|---|---|---|
| OD-1 | ADR-F D-1 says "no durable persistence in Epic 0"; this spec persists conversations in the PostgreSQL the backend already owns. Amend ADR-F or keep sessions in memory? | TL / Lautaro | Persist (as specified). The isolation property must survive a restart to be testable in CI, and ADR-F D-3's accessor pair exists to make the store swappable. |
| OD-2 | Retention for `sessions` / `messages` (the audit trail purges at `AUDIT_RETENTION_DAYS`) | Lautaro | None in this spec: a session lives until its owner deletes it. Add a purge job alongside `app/jobs/purge_audit.py` when the demo data volume justifies it. |
| OD-3 | Does the A2A adapter (ADR-J) map `contextId` onto this session id, or keep its own table? | TL | Map onto this id: ADR-A D-2 requires a `contextId` presented by the wrong subject to be treated as not-found, which is exactly `get_for_subject` returning `None`. |
| OD-4 | Should `DELETE` of an unknown id answer `204` (pure idempotence) or `404`? | Lautaro | `404`. Answering `204` for any id would make "does this session exist?" unanswerable but also make the isolation boundary untestable from the outside; RFC 9110 idempotence is about the effect on server state, which `404` preserves. |

## 9. Rollout & observability

`sessions.api` ships **enabled** (`default=True`) — there is no previous
behaviour to preserve — and can be switched off with
`PUT /v1/admin/feature-flags/sessions.api {enabled:false}` or the
`FEATURE_FLAGS_FORCE_DISABLED` kill-switch. Migration `0004` runs at container
start (`alembic upgrade head`) before the routes are reachable. Every session
action appears in `audit_events` with its `target`, so "who touched session X"
is one query; a 404 on a foreign session is indistinguishable in the response
but **is** visible in the trail as a `session.read` by the other subject, which
is the signal to alert on if the showcase is ever exposed publicly.
