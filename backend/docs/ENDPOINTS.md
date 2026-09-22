# Endpoints

GENERATED FILE — do not edit by hand. Regenerate with: `cd backend && make openapi-docs`

Every operation `GET /openapi.json` serves, read from the built application:
the method and path from the router, **Auth** and **Flag** from the route's
dependency tree (`api/route_facts.py`), the purpose from its `summary` and
the spec from its `description`. `make openapi-check` fails when this table
and the document disagree, so a route cannot ship undocumented here.

`public` routes need no token (`.claude/rules/backend/security.md`);
`bearer` ones take `Authorization: Bearer <token>`. A **Flag** names the
feature flag that answers 404 `feature-disabled` while it is off. The
interactive document is `/docs` and the raw one `/openapi.json`, both off
in production.

| Method | Path | Auth | Flag | Purpose | Spec |
|---|---|---|---|---|---|
| `GET` | `/health` | public | — | Report process liveness | 0001 |
| `GET` | `/readyz` | public | — | Report readiness of every dependency | 0001 |
| `GET` | `/v1/me/access` | bearer | — | Say whether the caller may use the preview | 0027 |
| `POST` | `/v1/access-requests` | public | — | Ask to be invited | 0027 |
| `POST` | `/v1/preview-sign-ins` | public | — | Sign in with a provisioned e-mail (local stacks only) | 0027 |
| `GET` | `/v1/admin/feature-flags` | bearer | — | List every persisted feature flag | 0002 |
| `PUT` | `/v1/admin/feature-flags/{key}` | bearer | — | Enable or disable a feature flag | 0002 |
| `GET` | `/v1/me` | bearer | — | Describe the authenticated caller | 0001 |
| `GET` | `/v1/me/audit-events` | bearer | `identity.audit` | List my recent audit events | 0001, 0002 |
| `GET` | `/v1/admin/users` | bearer | — | List the provisioned accounts | 0027 |
| `POST` | `/v1/admin/users` | bearer | — | Invite an account | 0027 |
| `PATCH` | `/v1/admin/users/{email}` | bearer | — | Change an account's status | ADR-B, 0027 |
| `GET` | `/v1/portfolios/{portfolio_id}/views` | bearer | `views.read` | Render one or more projections of a portfolio | ADR-K, 0005 |
| `POST` | `/v1/view-renders` | bearer | `views.batch-render` | Render several projections in one batch | ADR-K, 0012 |
| `GET` | `/v1/views` | bearer | `views.catalog` | List every projection the backend can render | ADR-K, 0005, 0022, 0023 |
| `GET` | `/.well-known/agent-card.json` | public | — | Describe this agent to a client | 0010 |
| `POST` | `/` | bearer | `agent.a2a` | Call an A2A method (JSON-RPC) | ADR-J, 0010 |
| `POST` | `/v1/sessions` | bearer | `sessions.api` | Open a conversation session | 0004 |
| `GET` | `/v1/sessions` | bearer | `sessions.api` | List my conversation sessions | 0004 |
| `GET` | `/v1/sessions/{session_id}` | bearer | `sessions.api` | Read one of my sessions | ADR-A, 0004 |
| `DELETE` | `/v1/sessions/{session_id}` | bearer | `sessions.api` | Delete one of my sessions | 0004 |
| `POST` | `/v1/sessions/{session_id}/messages` | bearer | `sessions.api` | Append a turn to one of my sessions | 0004 |
| `GET` | `/v1/sessions/{session_id}/messages` | bearer | `sessions.api` | Read the conversation of one of my sessions | 0004 |
