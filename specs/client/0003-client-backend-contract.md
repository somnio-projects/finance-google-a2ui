# 0003 — The contract the client binds to

- **Area:** client
- **Status:** Draft
- **Ticket:** [GGU-82](https://somniosoftware.atlassian.net/browse/GGU-82) (AC-7) · **Related specs:** [client/0001](0001-client-foundation.md) (foundation), [client/0002](0002-client-delivery.md) (delivery), [backend/0005](../backend/0005-presentation-layer.md), [backend/0010](../backend/0010-a2a-surface.md), [backend/0012](../backend/0012-delivery-followups.md), [backend/0019](../backend/0019-frozen-catalog-contract.md)
- **ADRs:** [ADR-K](../../docs/adr/ADR-K-response-shaping.md) (response shaping — the constraint this whole document hangs on), [ADR-J](../../docs/adr/ADR-J-rest-api-and-a2a-surface.md) (two surfaces), [ADR-E](../../docs/adr/ADR-E-money-representation.md) (money), [ADR-B](../../docs/adr/ADR-B-auth-credential-contract.md) (credential), [ADR-D](../../docs/adr/ADR-D-a2ui-streaming-transport.md) (streaming), [ADR-A](../../docs/adr/ADR-A-session-identity.md) (session identity)
- **Owner:** Lautaro Bertuzzi · **Date:** 2026-09-20

> **Every response body, header and event in this document was captured from a
> running stack** (`docker compose up`, `AUTH_PROVIDER=jwt`, seeded portfolio,
> `as_of` 2026-09-20T19:00:21Z) on 2026-09-20, not transcribed from types. The
> three places where a shape could not be captured are labelled **not
> captured** and say why. A hand-copied shape is a shape that drifts, and this
> document exists precisely to stop the frontend reading backend source.

## 1. Problem

The backend's contract is finished and the client's side of it is nowhere
written down. Seventeen operations, a `/v1/views` catalog, six component types
and an A2A root exist and are exhaustively documented **as a server**. What
does not exist is the document a Flutter developer reads to answer "what do I
send, what comes back, and what am I not allowed to do with it" — so every
frontend question currently ends in reading Python.

That is expensive in the ordinary way, and dangerous in a specific way. The
product invariant of this showcase is that **the client transforms nothing**
([ADR-K](../../docs/adr/ADR-K-response-shaping.md)). A developer who reads the
backend to find a number will find `Decimal` values sitting right next to the
pre-formatted strings, and will reasonably format one of them. §9 exists to
make that a review rejection rather than a judgement call.

## 2. Scope

**In.** The whole client-facing surface: authentication, the view catalog, the
six components with their real payloads and declared options, reading views
singly and in batches, caching and revalidation, the agent turn over A2A, the
two error shapes, and the prohibitions. Numbered ACs a client PR can cite.

**Out.**
- Flutter architecture, state management, file budget, test rules — [client/0001](0001-client-foundation.md).
- The client container, hosting and `BACKEND_BASE_URL` — [client/0002](0002-client-delivery.md).
- Anything under `client_flutter/app/`, `.github/workflows/client-ci.yaml` and the Flutter half of `.claude/ship-gate.json` — GGU-1 owns them (Timur's PRs #26 and #30).
- Session persistence across turns. The A2A adapter echoes `contextId` but loads **no history** (`a2a_service.py` says so in its own docstring): every turn starts empty. `POST /v1/sessions` and `/v1/sessions/{id}/messages` exist and are listed in §3, but nothing wires them into a turn yet. **The client must not assume the agent remembers the previous message.**

## 3. The two surfaces, and the seventeen operations

[ADR-J](../../docs/adr/ADR-J-rest-api-and-a2a-surface.md) splits the service in
two, and **a client that treats them the same way is wrong**. This is the
single most common mistake against this backend, so it leads.

| | `/v1/**` and the health routes | The A2A root (`POST /`) |
|---|---|---|
| Style | REST | JSON-RPC 2.0 |
| Content type | `application/json` | `text/event-stream` (or `application/json` for a refusal) |
| Failure | RFC 9457 `application/problem+json` at a **4xx/5xx** | JSON-RPC error object at **HTTP 200**, or a `failed` event *inside* a 200 stream |
| Used for | catalog, view reads, batches, identity, sessions, flags | conversation and streaming only |

Read that table twice. `POST /` answering `200` tells you nothing about whether
the call succeeded; `GET /v1/views` answering `200` tells you everything.

The full operation list, from the live `GET /openapi.json`:

| Method & path | Auth | `operationId` | Client uses it for |
|---|---|---|---|
| `POST /` | Bearer | `call_a2a_method` | the agent turn (§8) |
| `GET /.well-known/agent-card.json` | **none** | `read_agent_card` | bootstrap discovery (§8.1) |
| `GET /health` | **none** | `read_liveness` | liveness |
| `GET /readyz` | **none** | `read_readiness` | readiness |
| `GET /v1/views` | Bearer | `list_view_catalog` | the catalog (§5) |
| `GET /v1/portfolios/{portfolio_id}/views` | Bearer | `read_portfolio_views` | reading views (§6.1) |
| `POST /v1/view-renders` | Bearer | `create_view_render_batch` | cross-resource batches (§6.2) |
| `GET /v1/me` | Bearer | `read_current_identity` | who am I, which scopes |
| `GET /v1/me/audit-events` | Bearer | `list_my_audit_events` | — (not used by the demo client) |
| `POST /v1/sessions` | Bearer | `create_session` | out of scope, see §2 |
| `GET /v1/sessions` | Bearer | `list_sessions` | out of scope |
| `GET /v1/sessions/{session_id}` | Bearer | `read_session` | out of scope |
| `DELETE /v1/sessions/{session_id}` | Bearer | `delete_session` | out of scope |
| `POST /v1/sessions/{session_id}/messages` | Bearer | `append_session_message` | out of scope |
| `GET /v1/sessions/{session_id}/messages` | Bearer | `list_session_messages` | out of scope |
| `GET /v1/admin/feature-flags` | Bearer + `admin` scope | `list_feature_flags` | not for the client |
| `PUT /v1/admin/feature-flags/{key}` | Bearer + `admin` scope | `set_feature_flag` | not for the client |

Seventeen. `/health` and `/readyz` are the only non-versioned routes, and with
the agent card the only unauthenticated ones.

## 4. Auth

### 4.1 Which token, which provider

The backend verifies bearer tokens through one of two pluggable providers,
selected by `AUTH_PROVIDER` (`backend/src/app/auth/registry.py`). **The client
sends the same thing either way** — `Authorization: Bearer <jwt>` — and the
difference is whose signature the backend trusts.

| `AUTH_PROVIDER` | Algorithm | Verified against | Who uses it |
|---|---|---|---|
| `jwt` | HS256 | `AUTH_JWT_SECRET` | local dev and service-to-service. Mint with `cd backend && make token SUBJECT=alice`. |
| `oidc` | RS256 / ES256 | the issuer's JWKS (`AUTH_OIDC_JWKS_URL`) | every deployed environment — Firebase, Google, any SSO |

In production the credential is the **Firebase ID token**
([ADR-B](../../docs/adr/ADR-B-auth-credential-contract.md) D-1). The **refresh
token must never be sent to this backend**; ADR-B D-1 asks for a client test
asserting the outbound request carries none, and AC-3 below keeps it.

### 4.2 What the client sends

On every `/v1/**` call and on the A2A root:

```
Authorization: Bearer <idToken>
```

On the A2A root **additionally** `X-A2A-Extensions`, and this is a trap worth
stating plainly. `A2uiAgentConnector(url: …)` hardcodes `authHeaders` with
`X-A2A-Extensions` and gives no seam to add `Authorization`. The client must
use the `A2uiAgentConnector(client: A2AClient(…))` form **and re-supply
`X-A2A-Extensions` itself** — omit it and A2UI silently degrades to a text
agent, with no error (ADR-B, blocker 1). The header map must be **mutable**,
because `genui_a2a 0.10.1` has no interceptor and `HttpTransport.authHeaders`
is spread per request (ADR-B D-9); rewrite the `Authorization` entry before
each send.

### 4.3 Where the token lives

Never in a URL, never in a query string, never in a log, never in `renderIntent`
options. In memory for the lifetime of the app, refreshed from the Firebase SDK.
ADR-B D-10 forbids committing any credential, `google-services.json` or
`GoogleService-Info.plist`; only Firebase **public** config ships client-side.
The repo's permissions deny those paths outright (root `CLAUDE.md`).

### 4.4 401 vs 403, and what the client does about each

401 and 403 mean genuinely different things here and get different handling.
The `type` suffix is the machine-readable part — **branch on `type`, never on
`detail`** (`backend/src/app/schemas/problem.py` says so in its own docstring).

Captured, `AUTH_PROVIDER=jwt`:

```http
GET /v1/me            (no Authorization header)
HTTP/1.1 401 Unauthorized
content-type: application/problem+json
```
```json
{
  "type": "https://errors.finance-a2ui/auth/missing-token",
  "title": "Unauthorized",
  "status": 401,
  "detail": "No bearer token was supplied.",
  "instance": "/v1/me",
  "request_id": "3910c6da-876e-48ad-b374-55e67b1a0f4b"
}
```
```http
GET /v1/me            Authorization: Bearer not-a-token
HTTP/1.1 401 Unauthorized
```
```json
{
  "type": "https://errors.finance-a2ui/auth/invalid-token",
  "title": "Unauthorized",
  "status": 401,
  "detail": "token could not be verified",
  "instance": "/v1/me",
  "request_id": "1bd6d4f2-8fa0-4398-8df1-8e8d38159f8e"
}
```
```http
GET /v1/admin/feature-flags    Authorization: Bearer <valid token, no admin scope>
HTTP/1.1 403 Forbidden
```
```json
{
  "type": "https://errors.finance-a2ui/forbidden",
  "title": "Forbidden",
  "status": 403,
  "detail": "feature flags require the admin scope",
  "instance": "/v1/admin/feature-flags",
  "request_id": "413bbf44-d2e1-4ff2-b96a-bab92c5e0d3e"
}
```

The policy, from ADR-B D-7 — **force-refresh and exactly one retry, no loop**:

| `type` suffix | Status | What it means | Client does |
|---|---|---|---|
| `auth/missing-token` | 401 | no header was sent | attach the token and retry once; if it recurs, it is a client bug |
| `auth/expired-token` | 401 | signature valid, `exp` passed | **force-refresh the ID token, retry exactly once**, then sign out |
| `auth/invalid-token` | 401 | signature, issuer, audience or `kid` wrong | **sign out immediately** — no refresh, no retry |
| `forbidden` | 403 | authenticated, but lacks the scope | surface it; never retry, never refresh. The token is fine; the caller is not entitled |

`auth/expired-token` is emitted by **both** providers (`jwt_provider.py:44`,
`oidc_provider.py:52`, both catching `jwt.ExpiredSignatureError`), so D-7 is
implementable. *Not captured:* forcing a real expiry needs a clock the probe
could not move; verified by reading both providers.

> **Resolved divergence — `auth/revoked-token` does not exist, and a revoked
> token is not rejected at all.** ADR-B D-4 asked for `check_revoked=True` and
> D-6 listed `auth/revoked-token` → 401. Neither was ever built: `check_revoked`
> is a **Firebase Admin SDK** parameter and `firebase-admin` is not a dependency;
> `OidcTokenVerifier` is a generic JWKS verifier (`jwt.decode`). **A client must
> not write a branch for a code the backend cannot emit.**
>
> **What actually happens, which is not what this note said before.** A revoked
> token does **not** present as `auth/invalid-token`. Revoking a Firebase session
> invalidates the *refresh* token and sets a valid-since watermark; the ID token
> already in the client's hand keeps its valid signature, `iss`, `aud` and `exp`,
> and the backend consults no watermark (`auth/claims.py` never reads `auth_time`).
> For the remainder of that token's lifetime the request is **accepted, with a
> 200**. What signs the user out is **D-7**: at `exp` the client force-refreshes,
> the refresh fails at Firebase, and sign-out follows.
>
> **So the client needs no change, but for a different reason than "the backend
> rejects it".** Nothing here is rejected; the window is closed by expiry. Bound:
> **≤ 1 h + 30 s** for user ID tokens (Firebase's fixed one-hour lifetime plus
> `AUTH_LEEWAY_SECONDS`). A client must not present the session as revoked before
> then, and must not poll for a rejection that will not come.
>
> ADR-B **D-4 is struck and superseded by D-11/D-12**, and D-6's
> `auth/revoked-token` is struck (GGU-87, Proposed). The gap was the ADR's, and it
> is recorded there and in `backend/docs/SECURITY.md` as an accepted residual
> risk with an owner. See OD-3.

### 4.5 `GET /v1/me`

Captured:

```json
{ "subject": "alice", "provider": "jwt", "email": null, "scopes": [] }
```

`scopes` is the lower-cased union of the `scope`, `scp` and `roles` claims
(`auth/claims.py`), accepting either a space-separated string or a list. The
client reads `scopes` to decide what to *show*; the backend decides what to
*allow*. Hiding an admin control is a courtesy, not a control.

## 5. The catalog — discovering views at runtime

`GET /v1/views` is how a client learns what it may ask for without guessing
(ADR-K D-8). It describes **shapes, never portfolio data**, but still requires
a bearer token.

A real entry, captured (its `example` elided here — the same payload appears in
full in §7.2):

```json
{
  "id": "holdings.allocation.v1",
  "summary": "Allocation by holding: market value and portfolio weight per symbol, with a residual Other bucket for everything beyond top_n.",
  "endpoints": [
    "GET /v1/portfolios/{portfolio_id}/views",
    "POST /v1/view-renders"
  ],
  "options_schema": {
    "additionalProperties": false,
    "description": "Declared knobs of ``holdings.allocation.v1``; nothing else is accepted.",
    "title": "HoldingsAllocationOptions",
    "type": "object",
    "properties": {
      "top_n": {
        "default": 5, "type": "integer", "minimum": 1, "maximum": 20,
        "description": "How many rows to render before the residual bucket.", "examples": [5]
      },
      "include_other": {
        "default": true, "type": "boolean",
        "description": "Aggregate everything beyond `top_n` into an `Other` row.", "examples": [true]
      },
      "sort": {
        "default": "value_desc", "type": "string",
        "enum": ["value_desc", "value_asc", "label"],
        "description": "Row order: by value descending, ascending, or by label."
      },
      "precision": {
        "default": 2, "type": "integer", "minimum": 0, "maximum": 8,
        "description": "Decimal places for every figure this view renders."
      },
      "currency": {
        "const": "USD", "default": "USD", "type": "string",
        "description": "Currency of every figure. The portfolio is denominated in USD and the backend invents no exchange rate, so anything else is rejected rather than silently converted."
      }
    }
  },
  "example": { "…": "see §7.2" }
}
```

A `ViewDescriptor` carries exactly five fields (`schemas/view_catalog.py`):
`id`, `summary`, `endpoints`, `options_schema`, `example`.

### 5.1 What is stable, and what is versioned

| Fact | Stability |
|---|---|
| The **id grammar** `<component>.<variant>.v<N>` | stable. Pattern `^[a-z][a-z0-9]*(\.[a-z0-9_]+)+\.v[0-9]{1,3}$`, `max_length` 64 |
| A **specific id's payload shape** | frozen once published (ADR-K D-9). A change arrives as `…v2`, never as a mutation of `v1` |
| A specific id's **options** | frozen with it; options are additive within a version only if they are optional and defaulted |
| The **set of ids** | **not** stable — it grows. Six today; ADR-K D-15 makes adding one an additive, no-edit change |
| `summary`, `example` | informative, may be reworded; do not parse them |
| `endpoints` | stable for the two serving endpoints |

**Therefore the client must not hardcode the set of six**, and must not treat an
unknown id in a `renderIntent` as a crash. §9 turns that into a rule.

`docs/catalog/CONTRACT.md` carries a 12-character **digest** per component over
id, summary, endpoints, options schema, payload schema and example. If a `v1`
digest changes, something frozen moved. Today:

| Frozen id | Digest | Component | Inputs |
|---|---|---|---|
| `attribution.waterfall.v1` | `04a53053167d` | `AttributionWaterfall` | read-only |
| `holdings.allocation.v1` | `7c827ee9a8b8` | `HoldingsSummary` | read-only |
| `order.ticket.v1` | `6cbd19f8949e` | `OrderTicket` | `symbol`, `side` |
| `payoff.curve.v1` | `6a69670692d0` | `RiskPayoffChart` | read-only |
| `scenario.comparison.v1` | `fe62a7725690` | `ScenarioComparison` | `subject.symbol` |
| `taxlots.table.v1` | `c9cc43ace0f0` | `TaxLotTable` | read-only |

> **Every digest above moved on 2026-09-21** (GGU-53, spec `backend/0023`).
> Four components were renamed to the names the design catalog gives them, the
> catalog entry each digest is taken over now carries the component name and
> the model guidance, and two payloads gained the raw values a painter needs
> (`Bucket.key`, `SeriesPoint.at`). A moved digest is the mechanism working:
> something frozen changed, and it says so.

> Verified on 2026-09-20: for all six components, the `example` and `summary`
> served live by `GET /v1/views` are **byte-identical** to the ones frozen in
> `docs/catalog/CONTRACT.md`. The generated contract and the running API agree.

## 6. Reading views

### 6.1 `GET /v1/portfolios/{portfolio_id}/views` — repeated `?view=`

`portfolio_id` matches `^[a-z0-9-]{1,64}$`. Only the well-known **`current`**
exists today; it resolves to the authenticated caller's own portfolio.

Repeat `view` for up to **`MAX_VIEWS` = 4** projections in one request (ADR-K
D-17): one authentication, one session, one domain build, *N* pure renders. The
response is a **keyed object**, one entry per requested view id:

```http
GET /v1/portfolios/current/views?view=holdings.allocation.v1&top_n=2
HTTP/1.1 200 OK
etag: "de120f257d418e3875e…"
cache-control: private, no-cache
vary: Authorization
```
```json
{
  "as_of": "2026-09-20T19:00:21.231032Z",
  "portfolio_id": "current",
  "views": {
    "holdings.allocation.v1": {
      "view": "holdings.allocation.v1",
      "title": "Allocation by holding",
      "total": {
        "label": "Total market value",
        "amount": { "amount": "65038.6000000000000000000000", "display": "$65,038.60" }
      },
      "categories": [
        {
          "label": "Bitcoin", "key": "BTC",
          "value":  { "amount": "38550.00000000000000000000", "display": "$38,550.00" },
          "weight": { "value": "0.5927249356535964796290203049", "display": "59.27%" }
        },
        {
          "label": "Ethereum", "key": "ETH",
          "value":  { "amount": "15902.50000000000000000000", "display": "$15,902.50" },
          "weight": { "value": "0.2445086456350536450661607107", "display": "24.45%" }
        },
        {
          "label": "Other", "key": "other",
          "value":  { "amount": "10586.1000000000000000000000", "display": "$10,586.10" },
          "weight": { "value": "0.1627664187113498753048189844", "display": "16.28%" }
        }
      ]
    }
  }
}
```

Look at `weight`: `"0.5927249356535964796290203049"` beside `"59.27%"`. **The
client prints `display` and never touches `value`.** That pairing is
[ADR-E](../../docs/adr/ADR-E-money-representation.md) D-2 and it is the whole
argument of this document in three lines of JSON. The raw member exists so a
chart can compute geometry (a slice angle, a bar height), nothing else.

**The envelope always carries `as_of`** — the instant the portfolio was read,
fixed per session (ADR-F). Render it if you show a timestamp; never call
`DateTime.now()` for it.

**Omitting `view` entirely** invokes the documented selection rule (ADR-K
D-13): each projection scores itself through its own `fitness`, highest wins,
ties break on ascending id, and the endpoint's default `holdings.allocation.v1`
is used only when nothing scores above zero. Captured against the seeded
portfolio, `GET /v1/portfolios/current/views` with no `view` returned
`attribution.waterfall.v1` — **the default is not what you get**, it is the
fallback. Ask for what you want.

#### Options are shared across the whole request — and this bites

Options on this endpoint are **one flat set applied to every requested view**.
An option that only one of the requested views declares makes the **whole
request** a 422. Captured:

```http
GET /v1/portfolios/current/views
      ?view=holdings.allocation.v1&view=attribution.waterfall.v1&top_n=3
HTTP/1.1 422 Unprocessable Entity
```
```json
{
  "type": "https://errors.finance-a2ui/validation-failed",
  "title": "Unprocessable Entity",
  "status": 422,
  "detail": "view 'attribution.waterfall.v1' rejected option(s) ['top_n']",
  "instance": "/v1/portfolios/current/views",
  "request_id": "68eda88b-66f7-4e2f-8b3c-d801ba931787"
}
```

`holdings.allocation.v1` declares `top_n`; `attribution.waterfall.v1` does not.
So: **batch with `?view=` only when the views share their options** (or when
you pass none). Otherwise use §6.2, which gives every entry its own options.

Projection-specific options *do* work on this path — `symbol`, `side`, `size`,
`size_in`, `quantity`, `lot_method`, `methods`, `range_pct`, `steps` are all
accepted (`schemas/view_options.py`, added by PR #40 after the catalog and the
endpoint were found to disagree). Captured:
`GET /v1/portfolios/current/views?view=order.ticket.v1&symbol=ETH&side=sell&size=2`
→ `200`.

### 6.2 `POST /v1/view-renders` — cross-resource batches with per-entry status

When views span different resources, or need **different options each**, the
batch is a resource (ADR-K D-18). Up to **`MAX_RENDERS` = 8** entries, at most
**`MAX_OPTIONS` = 16** option keys per entry.

```http
POST /v1/view-renders
```
```json
{
  "renders": [
    { "view": "attribution.waterfall.v1", "portfolio_id": "current" },
    { "view": "nope.thing.v1",            "portfolio_id": "current" },
    { "view": "holdings.allocation.v1",   "portfolio_id": "current", "options": { "nope": 1 } }
  ]
}
```
```http
HTTP/1.1 201 Created
```

**201 with no `Location`** — deliberately. The batch is computed, not stored,
and inventing an address for it would be a lie in the contract (spec 0012
OD-1). Do not follow a `Location`; there is none.

Every entry carries **its own status**, so one bad entry never sinks the
others. Captured, from the three entries above:

| `status` | `view` | `error.detail` |
|---|---|---|
| `200` | `attribution.waterfall.v1` | — (`payload` present, `as_of` present) |
| `404` | `nope.thing.v1` | `view 'nope.thing.v1' is not registered` |
| `422` | `holdings.allocation.v1` | `view 'holdings.allocation.v1' rejected option(s) ['nope']` |

Result shape (`schemas/view_renders.py`): `status`, `view`, `portfolio_id`,
`as_of` (absent when the entry failed), `payload` (the projection, discriminated
by `view`) or `error` (a full `ProblemDetails`). Results come back **in request
order**. `response_model_exclude_none` is on, so absent means absent.

The batch itself answers 201 whenever it was *well formed*. A malformed, empty
(`min_length` 1) or oversized (> 8) body is a 422 for the whole request.

### 6.3 Choosing between them

| Situation | Use |
|---|---|
| One view | `?view=` |
| 2–4 views, same portfolio, same (or no) options | `?view=` repeated — one round trip, one `ETag`, revalidates as a unit |
| Views needing different options | `POST /v1/view-renders` |
| More than 4 views | `POST /v1/view-renders` (up to 8) |
| You want partial success | `POST /v1/view-renders` — `?view=` is all-or-nothing |

## 7. The six components

Six projections, six A2UI component types. The mapping is one adapter per
projection (`presentation/surfaces.py`), which is what keeps a `genui` /
`a2ui_core` bump a contained change — those packages are alpha.

A `Surface` carries `component`, `view`, `title` and `props`. **`props` are
already formatted**; the client binds them.

| Projection id | A2UI `component` | `props` keys | Declared options | Editable |
|---|---|---|---|---|
| `attribution.waterfall.v1` | `AttributionWaterfall` | `start`, `end`, `steps`, `notes` | `fields`, `locale`, `precision`, `currency` | — |
| `holdings.allocation.v1` | `HoldingsSummary` | `center`, `slices` | `top_n`, `include_other`, `sort`, `precision`, `currency` | — |
| `order.ticket.v1` | `OrderTicket` | `symbol`, `name`, `side`, `quantity`, `entryPrice`, `notional`, `inputs`, `effect`, `disclosure` | `locale`, `precision`, `currency`, `symbol`, `side`, `size`, `size_in` | **`symbol`, `side`** |
| `payoff.curve.v1` | `RiskPayoffChart` | `lines`, `markers`, `annotations`, `totals`, `disclosure` | `fields`, `locale`, `precision`, `currency`, `symbol`, `size`, `size_in`, `side`, `range_pct`, `steps` | — |
| `scenario.comparison.v1` | `ScenarioComparison` | `subject`, `columns`, `spread`, `notes` | `locale`, `precision`, `currency`, `symbol`, `quantity`, `methods` | **`subject.symbol`** |
| `taxlots.table.v1` | `TaxLotTable` | `rows`, `totals`, `byTerm`, `subtitle` | `fields`, `locale`, `precision`, `currency`, `symbol`, `quantity`, `lot_method` | — |

Note the `props` keys are **camelCase** while the payload fields are
**snake_case** (`entry_price` → `entryPrice`). The adapter does that rename;
the client binds whichever it is handed and renames nothing itself.

### 7.1 What "editable" means, precisely

> **An editable field is a payload field named exactly as the option that sets
> it. That naming *is* the interactivity declaration.**

There is no separate "editable" flag and there must never be one. The widget
shows `payload.symbol`, the user changes it, the client re-requests **the same
view** with `?symbol=…`, and the backend re-renders. The round trip is
closed because the option validates in the registry (ADR-K D-3).

`docs/catalog/CONTRACT.md` derives the **Input** column from exactly this name
match, and its bounds are the validation the design must respect — *the client
does not invent its own*. A component needing an input that does **not**
round-trip through a declared option is a **contract error**, not a missing
column: the client would be sending the backend something the registry cannot
validate. Raise it; do not work around it.

`order.ticket.v1` additionally ships an `inputs[]` array that **describes its
own controls** — see §7.3. That array is the honest way to build the form:
labels, control kinds, current values, choices and patterns all come from the
server.

### 7.2 `holdings.allocation.v1` → `HoldingsSummary`

Payload captured in §6.1. Options: `top_n` (1–20, default 5), `include_other`
(default true), `sort` (`value_desc` | `value_asc` | `label`), `precision`
(0–8, default 2), `currency` (`USD` only). Read-only.

The residual bucket arrives as a normal category with `"key": "other"` — the
client does not compute it, does not decide when it appears, and does not sum
the rest to check. `include_other=false` simply omits it.

### 7.3 `order.ticket.v1` → `OrderTicket` — the interactive one

Captured in full:

```json
{
  "view": "order.ticket.v1",
  "title": "Proposed order",
  "symbol": "BTC",
  "name": "Bitcoin",
  "side": "buy",
  "quantity":    { "units": "1", "display": "1" },
  "entry_price": { "amount": "64250.00", "display": "$64,250.00" },
  "notional": {
    "label": "Order value",
    "amount": { "amount": "64250.00", "display": "$64,250.00" }
  },
  "inputs": [
    { "option": "symbol",  "label": "Asset",   "control": "choice",
      "value": "BTC",   "choices": ["ADA","AVAX","BTC","DOGE","DOT","ETH","LINK","SOL"], "pattern": null },
    { "option": "side",    "label": "Side",    "control": "choice",
      "value": "buy",   "choices": ["buy","sell"], "pattern": null },
    { "option": "size",    "label": "Size",    "control": "text",
      "value": "1",     "choices": [], "pattern": "^[0-9]{1,9}(\\.[0-9]{1,8})?$" },
    { "option": "size_in", "label": "Size in", "control": "choice",
      "value": "units", "choices": ["units","usd"], "pattern": null }
  ],
  "effect": "recalculate",
  "disclosure": "Illustrative ticket. This showcase has no broker and no execution: changing a field re-renders these figures, and nothing is ever sent, placed or settled."
}
```

Everything the form needs is in `inputs[]`: `option` is the query parameter to
send, `label` is the caption to print, `control` picks the widget (`choice` →
picker, `text` → field), `value` is the current value, `choices` populates the
picker, `pattern` is the regex to validate against. **Build the form from this
array**, not from a hardcoded list of four controls — a fifth input appearing
must not require a client release.

`effect: "recalculate"` is a constant: editing re-renders, it never submits.
`disclosure` is server-written text and must be displayed verbatim — it is the
"this places no order" statement, and dropping it changes what the demo claims.

The size input is a **decimal string**, not a number
([ADR-E](../../docs/adr/ADR-E-money-representation.md) D-7): round-tripping
through a float reintroduces exactly the drift the ADR exists to prevent. Send
`"0.25"`, never `0.25`.

### 7.4 `scenario.comparison.v1` → `ScenarioComparison`

Captured (abridged to two of three columns; the third, `HIFO`, has the same
shape):

```json
{
  "view": "scenario.comparison.v1",
  "title": "Same sale, different lot method",
  "subject": {
    "label": "Bitcoin", "symbol": "BTC", "quantity_display": "0.18",
    "price":    { "amount": "64250.00", "display": "$64,250.00" },
    "proceeds": { "amount": "11565.00000000000000000000", "display": "$11,565.00" }
  },
  "columns": [
    {
      "method": "FIFO", "label": "FIFO — oldest lots first",
      "cost_basis":    { "amount": "7740.000000", "display": "$7,740.00" },
      "realized_pl":   { "amount": "3825.00000000000000000000", "display": "+$3,825.00" },
      "short_term_pl": { "amount": "0", "display": "$0.00" },
      "long_term_pl":  { "amount": "3825.00000000000000000000", "display": "+$3,825.00" },
      "short_term_lots": 0, "long_term_lots": 1, "lots": ["lot-btc-01"]
    },
    {
      "method": "LIFO", "label": "LIFO — newest lots first",
      "cost_basis":    { "amount": "10260.000000", "display": "$10,260.00" },
      "realized_pl":   { "amount": "1305.00000000000000000000", "display": "+$1,305.00" },
      "short_term_pl": { "amount": "1305.00000000000000000000", "display": "+$1,305.00" },
      "long_term_pl":  { "amount": "0", "display": "$0.00" },
      "short_term_lots": 1, "long_term_lots": 0, "lots": ["lot-btc-02"]
    }
  ],
  "spread": {
    "amount": { "amount": "2520.00000000000000000000", "display": "$2,520.00" },
    "differs": true, "highest": "FIFO", "lowest": "LIFO"
  },
  "notes": [
    { "label": "Before tax", "text": "The realised result and its short/long split, before any tax rate, fee or wash-sale rule." },
    { "label": "Not advice", "text": "No method is recommended: which result is preferable depends on a tax situation this demo does not know." }
  ]
}
```

Three things the client must not do here, all tempting:

- **`spread.highest` / `spread.lowest` are given.** Do not scan `columns` to find the best method — the backend already did, and it decided the tie-breaking rule.
- **`spread.differs` is a flag.** Do not compare the amounts to decide whether to show the spread.
- **`notes[]` are server-written and must be rendered.** The "Not advice" note is a compliance statement, not decoration. `methods` selects which columns appear (up to 3); the client does not filter them client-side.

The sign is baked in: `"+$3,825.00"`. The client does not prepend `+` or pick a
colour from the number — use `realized_pl.display` for the text, and if a
colour is needed, derive it from the sign of the **raw** value, never by
parsing the string.

### 7.5 `attribution.waterfall.v1` → `AttributionWaterfall`

Captured (abridged to two of five buckets):

```json
{
  "view": "attribution.waterfall.v1",
  "title": "Unrealised P/L attribution",
  "start": { "label": "Cost basis",   "amount": { "amount": "56925.000000000000000000",   "display": "$56,925.00" } },
  "end":   { "label": "Market value", "amount": { "amount": "65038.6000000000000000000000", "display": "$65,038.60" } },
  "buckets": [
    { "label": "Bitcoin",
      "delta":      { "amount": "10230.00000000000000000000", "display": "$10,230.00" },
      "cumulative": { "amount": "67155.00000000000000000000", "display": "$67,155.00" },
      "direction": "up" },
    { "label": "Ethereum",
      "delta":      { "amount": "-2797.50000000000000000000", "display": "-$2,797.50" },
      "cumulative": { "amount": "64357.50000000000000000000", "display": "$64,357.50" },
      "direction": "down" }
  ],
  "annotations": []
}
```

`cumulative` is supplied per bucket — **the client does not run the running
total**, which is the single most likely place for a waterfall to disagree with
its own endpoints. `direction` is an enum (`up`/`down`) for the variant; do not
test the sign of `delta.amount` to pick a colour. Buckets arrive largest-mover
first; `sort` is not an option here, so do not reorder them.

Options: `fields`, `locale`, `precision`, `currency`. Read-only.

### 7.6 `payoff.curve.v1` → `RiskPayoffChart` and `taxlots.table.v1` → `TaxLotTable`

Both follow the same discipline and are the two largest payloads (18 and 49
fields). Rather than reprint them, the client binds:

- **`payoff.curve.v1`** → `props`: `lines`, `markers`, `totals`, `disclosure`. `series` carries the points (each a `*Display` pair beside its raw figure), `annotations` carries entry and break-even as **server-computed markers** — the client does not solve for break-even. Options: `fields`, `locale`, `precision`, `currency`, `symbol`, `size`, `size_in`, `side`, `range_pct` (5–90), `steps` (1–25; the line is `2 × steps + 1` points). It is an **illustrative linear spot payoff**, never an options payoff, and `disclosure` says so — render it.
- **`taxlots.table.v1`** → `props`: `rows`, `totals`, `byTerm`, `subtitle`. `by_term` is the pre-split short/long-term summary; each row carries `acquired_on_display` and `units_display` beside its raw pair. (`remaining` and the `Price` total were withdrawn by spec `backend/0024` §7 — nothing bound them.) Options: `fields`, `locale`, `precision`, `currency`, `symbol`, `quantity`, `lot_method` (`FIFO` | `LIFO` | `HIFO`). The short/long-term classification is the backend's — **do not compute a holding period from dates in the client.**

Full field inventories for both, with per-field binding and state, are in
[`docs/catalog/CONTRACT.md`](../../docs/catalog/CONTRACT.md). That document is
regenerated and diffed by `make gate`, so it cannot drift from the registry;
bind against it.

### 7.7 The `fields` option

`fields` (≤ 8 entries, each `^[a-z_]{1,32}$`) trims sections the widget does not
bind, keeping the payload small (ADR-K D-21). A section the view does not offer
is **rejected, never ignored**. It is an optimisation, not a feature: a widget
that asks for fewer sections must still render correctly when it gets all of
them.

## 8. The agent turn

### 8.1 Bootstrap: the agent card

`GET /.well-known/agent-card.json` is **unauthenticated by contract** — a
client cannot hold a token before it has read this (ADR-B D-3). Captured:

```json
{
  "name": "finance-a2ui-backend",
  "description": "Answers questions about a simulated investment portfolio by composing interface from a fixed catalog rather than by writing prose. Every figure comes from a deterministic tool; the model never computes one.",
  "url": "http://localhost:8000",
  "version": "0.1.0",
  "protocolVersion": "0.9",
  "defaultInputModes": ["text/plain"],
  "defaultOutputModes": ["text/plain", "application/json"],
  "capabilities": { "streaming": true, "pushNotifications": false, "stateTransitionHistory": false },
  "skills": [
    { "id": "compute_attribution",   "name": "compute attribution",   "tags": ["finance","portfolio"], "description": "…" },
    { "id": "get_holdings_summary",  "name": "get holdings summary",  "tags": ["finance","portfolio"], "description": "…" },
    { "id": "payoff",                "name": "payoff",                "tags": ["finance","portfolio"], "description": "…" },
    { "id": "simulate_sale",         "name": "simulate sale",         "tags": ["finance","portfolio"], "description": "…" }
  ]
}
```

`url` is the A2A endpoint to post to. `capabilities.pushNotifications` is
`false` and `stateTransitionHistory` is `false` — **do not build against
either**; the honesty rule of this repo is that a document never implies a
capability that does not exist.

### 8.2 `message/stream`

The only method implemented today. Anything else is refused (§8.5).

```http
POST /
Authorization: Bearer <token>
Content-Type: application/json
Accept: text/event-stream
```
```json
{
  "jsonrpc": "2.0",
  "id": "req-1",
  "method": "message/stream",
  "params": {
    "message": {
      "role": "user",
      "messageId": "m-1",
      "contextId": "c2f1b8a4-3d5e-4a7b-9c11-8e2f6d0a1b33",
      "parts": [{ "kind": "text", "text": "What moved my portfolio this month?" }]
    }
  }
}
```

Response headers, captured: `content-type: text/event-stream; charset=utf-8`,
`cache-control: no-store`.

`contextId` is **echoed for correlation and nothing more** — it is resolved
against the authenticated subject or treated as unknown, never trusted on its
own (ADR-J D-4, ADR-A). Omit it and every event carries `"contextId": null`,
which is not an error.

### 8.3 Every event kind, in order — a real transcript

Captured end to end through the production `A2aService`, event builders and SSE
framing (`taskId` and `contextId` are real values from the run):

```
data: {"kind":"status-update","taskId":"7b1e2c44-…","contextId":"c2f1b8a4-…","status":{"state":"working"},"final":false}

data: {"kind":"render-intent","taskId":"7b1e2c44-…","contextId":"c2f1b8a4-…","index":0,"renderIntent":{"view":"attribution.waterfall.v1","options":{}}}

data: {"kind":"message","taskId":"7b1e2c44-…","contextId":"c2f1b8a4-…","role":"agent","parts":[{"kind":"text","text":"Your portfolio is up on the month; NVDA is the biggest contributor. The waterfall below walks the move."}],"renderIntents":[{"view":"attribution.waterfall.v1","options":{}}]}

data: {"kind":"status-update","taskId":"7b1e2c44-…","contextId":"c2f1b8a4-…","status":{"state":"input_required"},"final":true}
```

*Capture note:* the model was the repo's own `NullModelClient` scripted with one
`compute_attribution` call, because the live provider path is broken today (§8.6).
The tools, the projections, the event builders and the SSE bytes are the real
production code path; only the model's choice was scripted. An equivalent
envelope from the fully live path, with no tool call, is in §8.4.

The order, always:

1. **`status-update`** with `status.state: "working"`, `final: false` — the turn opened.
2. **zero or more `render-intent`**, one per surface, *while the turn is still running* (ADR-K D-19). `index` counts from 0. `renderIntent` is `{view, options}` and nothing else — it names a **registered** view; it never carries a payload. **The client fetches the payload itself** via §6, or renders from the catalog example.
3. **`message`** — `role: "agent"`, `parts[]` (`kind: "text"`), and `renderIntents[]` repeating **every** intent of the turn.
4. **`status-update`** with `final: true` and a terminal state.

**Terminal state matters:**

| `status.state` | Meaning | Client |
|---|---|---|
| `completed` | turn finished, no surface awaits the user | done |
| `input_required` | the turn produced a surface the user may act on | **normal terminal state, not an error** (ADR-D D-3) |
| `failed` | the turn could not be completed | §8.5 |

`input_required` is emitted whenever `renderIntents` is non-empty — which is the
common case for this app. A client that treats it as a failure will show an
error on every successful widget-bearing turn.

**Two ways to consume, both valid.** Render each `render-intent` as it lands
(first pixel early — the budget is **< 1 s to the first streamed surface**), or
ignore them and read `renderIntents` off the terminal `message`. They carry the
same surfaces; the incremental events are additive. Pick one and be consistent.

### 8.4 The same envelope, fully live

Captured from the running stack with no model provider configured (the
`NullModelClient` path), which exercises the complete HTTP + SSE route:

```
data: {"kind":"status-update","taskId":"f8bd99a6-…","contextId":"c2f1b8a4-…","status":{"state":"working"},"final":false}

data: {"kind":"message","taskId":"f8bd99a6-…","contextId":"c2f1b8a4-…","role":"agent","parts":[{"kind":"text","text":"The assistant is running without a model provider, so it can only confirm that the service is up."}],"renderIntents":[]}

data: {"kind":"status-update","taskId":"f8bd99a6-…","contextId":"c2f1b8a4-…","status":{"state":"completed"},"final":true}
```

Note `renderIntents: []` → terminal state `completed`, exactly as §8.3's table
says.

### 8.5 How a failure arrives

**A failed turn is still HTTP 200.** The client has already received the status
line and headers by the time a turn can fail, so the failure is reported
*inside* the stream. Captured from the running stack:

```
data: {"kind":"status-update","taskId":"0f26309c-…","contextId":null,"status":{"state":"working"},"final":false}

data: {"kind":"status-update","taskId":"0f26309c-…","contextId":null,"status":{"state":"failed"},"final":true}

data: {"kind":"error","taskId":"0f26309c-…","code":"dependency-unavailable","message":"model provider unavailable"}
```

**The `error` event arrives *after* the `final: true` status-update.** A client
that stops reading at `final: true` will show "failed" with no reason. Read to
end of stream.

`code` is a safe, stable identifier and `message` is safe text — never provider
text, never a URL, never a status line (`gemini_client.py` enforces this).

A refusal *before* the envelope is parsed is a **JSON-RPC error object at HTTP
200**. Captured:

```http
POST /   {"jsonrpc":"2.0","id":"1","method":"no/such","params":{}}
HTTP/1.1 200 OK
content-type: application/json
```
```json
{ "jsonrpc": "2.0", "id": "1", "error": { "code": -32601, "message": "Unknown method." } }
```

And a failure *before authentication* is an ordinary RFC 9457 problem document
at **401** — captured, `POST /` with no token → `401`. So the A2A root can
answer in **three** shapes, and a client parses all three:

| Condition | Status | Body |
|---|---|---|
| Unauthenticated | 401 | RFC 9457 problem document |
| Bad envelope / unknown method | 200 | JSON-RPC error object |
| Turn ran and failed | 200 | SSE stream ending in `failed` + `error` |
| Turn succeeded | 200 | SSE stream ending in `completed` / `input_required` |

### 8.6 Known defect — the live model path is broken today

*Not captured (and it cannot be):* a fully live turn that reaches a tool. With
a valid `GEMINI_API_KEY` configured, `POST /` returns the §8.5 failure for
**every** turn. The provider rejects the request with 400:

```
Invalid JSON payload received. Unknown name "additionalProperties" at
  'tools[0].function_declarations[0].parameters': Cannot find field.
Invalid JSON payload received. Unknown name "examples" at
  'tools[0].function_declarations[0].parameters.properties[0].value': Cannot find field.
```

`infra/model/payload.py:to_request` passes each tool's raw pydantic JSON Schema
straight into `functionDeclarations[].parameters`, which accepts only a
restricted OpenAPI-3.0 subset — `additionalProperties`, `examples`, `title` and
`anyOf` are not in it. This is what branch `fix/GGU-36_gemini_tool_schema` is
for. **The client contract is unaffected** — the event shapes in §8.3–8.5 are
the contract, and they are pinned by
`tests/unit/services/test_a2a_streaming.py` and
`tests/unit/api/test_a2a_examples.py` regardless of which model runs — but a
frontend developer must know that a local `POST /` will fail until that lands,
and must not "fix" it client-side.

## 9. What the client must never do

**This is the section that matters most.** Every prohibition below is a server
responsibility **by decision, not by accident**, and each names the decision.
A reviewer rejects a PR that breaks one; none of them is a style preference.

| # | The client must never… | Because | A reviewer rejects |
|---|---|---|---|
| N-1 | **Format a number.** No `toStringAsFixed`, no `NumberFormat`, no currency symbol, no thousands separator, no percent sign, no `+`/`−` prefix. | ADR-E D-2/D-3: `Decimal` → string happens in **one** module, server-side, `ROUND_HALF_EVEN`. Every figure already arrives as a `*Display` string. | any Dart that turns a number into text for display |
| N-2 | **Compute a figure.** No sums, no differences, no percentages, no running totals, no break-even, no weights, no spreads. | ADR-K D-5 and the numbers-from-tools product invariant: the LLM never computes a financial figure and neither does the client. `cumulative`, `spread`, `by_term`, `markers` are all supplied. | arithmetic on any payload value |
| N-3 | **Derive a field.** If the widget needs a value the payload does not carry, the **payload is missing a field** — raise it. Do not reconstruct it. | `CONTRACT.md`: "if a number has to appear on screen and only `raw` carries it, the payload is missing a field — raise it rather than formatting it in the client." | any value on screen with no `display`/`text` source |
| N-4 | **Print a raw figure.** `amount`, `value`, `units` are for geometry only. `"0.5927249356535964796290203049"` must never reach a user. | ADR-E D-5, ADR-K D-5: the raw member accompanies the display string, never replaces it. | binding `.amount` or `.value` to a text widget |
| N-5 | **Interpret a template.** No expression, no field path, no format string, no jbuilder-style directive sent to or evaluated from the server. | ADR-K D-3 and its neglected alternative: an open interpreter is an injection and DoS surface that cannot be documented or covered. | any string from the server used as code or a path |
| N-6 | **Invent a view id.** Only ids from `GET /v1/views` may be sent. An id the client constructs, guesses or hardcodes-and-forgets is a 404. | ADR-K D-12: the model picks from the registry and never invents a shape; the client is held to the same rule. | a view id literal not sourced from the catalog |
| N-7 | **Send an undeclared option.** Options come from `options_schema`; bounds are the server's. | ADR-K D-3: anything undeclared or out of range is a 422, never a best-effort guess. | a query parameter not in the view's options schema |
| N-8 | **Re-validate or second-guess a bound.** Use the `pattern`, `choices` and ranges the server sent; do not add stricter client rules. | §7.1: those bounds *are* the validation the design must respect. | a hardcoded regex or min/max beside a server-supplied one |
| N-9 | **Drop a disclosure or a note.** `disclosure`, `notes[]` and server-written `label`/`text` are rendered verbatim. | They are compliance statements ("nothing is ever placed", "not advice"), not decoration. | a payload text field present but unrendered |
| N-10 | **Reorder, filter or re-rank rows.** Buckets arrive largest-mover first; `sort`, `top_n`, `methods`, `lot_method` are **options**, not client behaviour. | ADR-K D-13: the ordering rule is code, it is tested, and it lives server-side so the demo is reproducible. | a client-side `sort`/`where` over payload rows |
| N-11 | **Treat `input_required` as an error.** | ADR-D D-3: a turn that produced a surface awaiting the user is a normal terminal state. | an error path keyed on a non-`completed` terminal state |
| N-12 | **Assume the A2A root's 200 means success.** | ADR-J D-3: that surface reports failures at HTTP 200, in two different shapes. | a success branch keyed on the A2A status code |
| N-13 | **Call `DateTime.now()` for `as_of`.** | ADR-F: `as_of` is fixed at seed time and travels in the envelope. | a client clock read used as portfolio time |
| N-14 | **Put a token in a URL, a query string or a log.** | ADR-B D-10, `security.md`: no secrets, tokens or PII in logs. | a token outside an `Authorization` header |
| N-15 | **Send a float where a decimal string is declared.** | ADR-E D-7: round-tripping through `float` reintroduces the exact drift the ADR prevents. | `size`/`quantity` sent as a JSON number |

**The one-line version, for a PR description:** *the backend shapes every
payload; the client binds it.* If a Dart file needs `dart:math`, `NumberFormat`
or a `fold` over a payload list to put something on screen, it is wrong.

## 10. Acceptance criteria

1. **AC-1** — The client sends `Authorization: Bearer <token>` on every `/v1/**` request and on `POST /`, and sends `X-A2A-Extensions` alongside it on `POST /`. A test asserts the A2A request carries both.
2. **AC-2** — The A2A connector is built with the `A2uiAgentConnector(client: A2AClient(…))` form over a **mutable** header map whose `Authorization` entry is rewritten before each send (ADR-B D-9). A test asserts a refreshed token reaches the next request.
3. **AC-3** — No outbound request to this backend carries a Firebase **refresh** token (ADR-B D-1). A test asserts this explicitly.
4. **AC-4** — On `auth/expired-token` the client force-refreshes and retries **exactly once**; on `auth/invalid-token` or a second `auth/expired-token` it signs out; on `403` it surfaces the error without refreshing or retrying. Tests cover all four branches, keyed on the problem document's `type`, never its `detail`.
5. **AC-5** — The client discovers views from `GET /v1/views` at runtime. No view id is hardcoded outside a test fixture, and an unknown id in a `renderIntent` degrades gracefully rather than crashing (§5.1).
6. **AC-6** — Each of the six components binds its real payload: `AttributionWaterfall`, `HoldingsSummary`, `OrderTicket`, `RiskPayoffChart`, `ScenarioComparison`, `TaxLotTable`. A golden test per component renders the `example` from `GET /v1/views` — the same payload frozen in `docs/catalog/CONTRACT.md`.
7. **AC-7** — Every figure on screen comes from a `*Display` string or a server-written text field. A test asserts that no widget binds a `raw` numeric member to a text widget (N-1, N-4).
8. **AC-8** — The client performs no financial arithmetic. A lint or review check keeps `dart:math`, `NumberFormat` and arithmetic operators out of payload-binding code paths (N-2, N-3).
9. **AC-9** — `order.ticket.v1` builds its form from `inputs[]`: labels, control kinds, choices and patterns all come from the payload, and a fifth input renders with no client change (§7.3).
10. **AC-10** — Editing an editable field re-requests the **same view id** with that field's name as the option, and renders whatever comes back. A test covers `order.ticket.v1`'s `symbol` and `side` (§7.1).
11. **AC-11** — `size` and `quantity` are sent as decimal **strings** matching the server's `pattern`, never as JSON numbers (N-15).
12. **AC-12** — The client batches with repeated `?view=` (≤ 4) only when the requested views share their options, and uses `POST /v1/view-renders` (≤ 8) otherwise. A test covers the 422 of §6.1 and the per-entry statuses of §6.2.
13. **AC-13** — The client stores each response's `ETag` and sends `If-None-Match` on revalidation, treating **304** as "the body I already hold is current" (§11). A test asserts a 304 does not clear the cached view.
14. **AC-14** — The client renders `as_of` from the response envelope and never from a device clock (N-13).
15. **AC-15** — The agent turn handles all four event kinds in order, treats `input_required` as a **success** terminal state, and reads to end of stream so the `error` event after `final: true` is not missed (§8.3, §8.5).
16. **AC-16** — The client parses all three A2A response shapes: a 401 problem document, a JSON-RPC error at 200, and an in-stream `failed` + `error` (§8.5). A test covers each.
17. **AC-17** — Every `disclosure` and `notes[]` entry a bound payload carries is rendered (N-9). A test asserts `order.ticket.v1`'s disclosure and `scenario.comparison.v1`'s two notes appear.
18. **AC-18** — A PR touching payload binding cites this spec and states which of N-1…N-15 it was checked against.

## 11. Caching and revalidation

Projections are cacheable because they are pure (ADR-K D-20). Every view read
carries, captured:

```
etag: "de120f257d418e3875e…"
cache-control: private, no-cache
vary: Authorization
```

- The **strong** `ETag` (no `W/` prefix) is `sha256` over *(resource, subject, view ids, options, `as_of`)* — `api/caching.py:strong_etag`. Same request, same bytes, for the life of the session.
- `private` because every body is subject-scoped. `no-cache` — **not** `no-store` — means *keep it, but ask before reusing it*: a feature flag can switch a route off at any moment, and a `max-age` would let a disabled endpoint keep rendering client-side.
- `Vary: Authorization` says it twice, because the failure mode is serving one caller's portfolio to another.

Revalidate by echoing the tag:

```http
GET /v1/views
If-None-Match: "338da930c616ee8090c80e2dcc77d446cce2bdc61d20d0d1dba64e1b24a5d138"

HTTP/1.1 304 Not Modified
etag: "338da930c616ee8090c80e2dcc77d446cce2bdc61d20d0d1dba64e1b24a5d138"
cache-control: private, no-cache
vary: Authorization
```

Captured against both `GET /v1/views` and the four-view
`GET /v1/portfolios/current/views?view=…×4` — both answered **304** with the
same tag and no body. Comparison is weak per RFC 9110 §13.1.2, so echoing
`W/"x"` for a strong `"x"` also matches.

**A 304 is not an error and not an empty result.** The cached body is still
current; render it. The client keys its cache on the full request URL plus the
subject, and drops every entry on sign-out (`private`).

The catalog's tag is a **process constant** — the registry cannot change after
import — so `GET /v1/views` revalidates for the price of one header and the
client can hold the catalog for the whole session.

**Latency budget** the client is measured against (ADR-K): **p95 < 150 ms**
warm for a projection read, **< 400 ms** cold, **< 1 s** to the first streamed
surface. A widget that misses it is a defect, and the fix is never to move work
into the client.

## 12. Error reference

Every `/v1/**` error is RFC 9457 `application/problem+json` with `type`,
`title`, `status`, `detail`, `instance` and `request_id`. **Branch on `type`;
log `request_id`** — it correlates with the backend's structured logs and is
the only thing worth pasting into a bug report.

| Status | Typical `type` suffix | Means | Client |
|---|---|---|---|
| 200 | — | rendered | bind it |
| 201 | — | batch created and rendered inline (§6.2) | read per-entry `status` |
| 304 | — | your cached body is current | render the cached body |
| 400 | `malformed-request` | body could not be read | bug; report with `request_id` |
| 401 | `auth/missing-token`, `auth/invalid-token`, `auth/expired-token` | see §4.4 | refresh-once, or sign out |
| 403 | `forbidden` | authenticated, lacks the scope | surface; never retry |
| 404 | `portfolio/unknown-view` | unregistered view id | re-read the catalog; never hardcode ids (N-6) |
| 404 | — | unknown portfolio, **or a feature flag is off** | a 404 here can mean "disabled", not "missing" |
| 422 | `validation-failed` | a view rejected an option — `detail` names the view and the option | fix the request; see §6.1's shared-option trap |
| 422 | `malformed-request` | a query parameter failed the endpoint's own bounds (unknown parameter, > 4 views, out-of-range value) | fix the request |
| 429 | — | rate limited | back off; do not hammer |
| 500 | — | unexpected | report with `request_id` |
| 503 | `dependency-unavailable` | a dependency is down | retry with backoff |

Two 422s with different `type`s is not an accident: `malformed-request` comes
from the endpoint's own query model (`ViewQuery`, `extra="forbid"`), and
`validation-failed` comes from the **projection's** options model. The first
says "this endpoint does not take that"; the second says "that view does not
take that". Only the second names the view in `detail`.

Feature flags gate `views.catalog`, `views.read` and `views.batch-render`. A
flag that is off answers **404**, deliberately — a disabled feature is
indistinguishable from a missing one.

## 13. Open decisions

| # | Question | Owner | Default if unresolved |
|---|---|---|---|
| OD-1 | Does the client render a `render-intent` incrementally, or wait for the terminal `message`? Both are supported (§8.3); incremental is what buys the < 1 s first-surface budget, at the cost of a more complex widget lifecycle. | Client lead (Timur) | incremental, since the budget is the reason the events exist |
| OD-2 | When a `render-intent` arrives, does the client fetch the payload via `GET …/views?view=<id>` or render from the catalog `example`? The intent carries no payload. | Client lead + TL | fetch, so the widget shows real portfolio data rather than the sample |
| OD-3 | ~~`auth/revoked-token` and `check_revoked=True` (ADR-B D-4/D-6) are not implemented (§4.4). Amend ADR-B to match the code, or implement revocation.~~ **Resolved 2026-09-20 (GGU-87): the ADR was amended.** D-4 is struck and superseded by D-11 (what verification asserts) and D-12 (no revocation check; latency = the token's remaining lifetime, **≤ 1 h + 30 s**), and `auth/revoked-token` is struck from D-6 — both Proposed, awaiting TL ratification. **No client change.** Note the corrected mechanism in §4.4: a revoked token is *accepted* until `exp`, not rejected as `auth/invalid-token`; D-7's failed refresh is what signs the user out. | TL | — resolved; ratification of ADR-B D-11/D-12 is the only thing still open |
| OD-4 | Conversation history: `contextId` is echoed but no history is loaded (§2). Which spec wires `/v1/sessions` into a turn? | TL | a backend spec, before the demo; the client should not simulate history locally |
| OD-5 | How does the client cache across a cold start — in-memory only, or persisted with its `ETag`? `Cache-Control: private` permits persistence for the signed-in user; it must be dropped on sign-out. | Client lead | in-memory only, until the latency budget demands otherwise |
| OD-6 | Which `genui` / `a2ui_core` version the six components bind to. They are alpha and their catalog will move; the adapter indirection (§7) is what contains a bump. | Client lead | pin exactly, and record the version in `client_flutter/CLAUDE.md` |

## 14. Test plan

This spec ships no code, so it has no tests of its own; its ACs are discharged
by the client PRs that cite them.

| AC | Where it is proven |
|---|---|
| AC-1…AC-4 | `client_flutter/app/test/` auth + connector tests (GGU-1 owns the harness) |
| AC-5, AC-6 | catalog discovery test + one golden test per component, against the `example` from `GET /v1/views` |
| AC-7, AC-8 | widget tests plus a static check over payload-binding code |
| AC-9…AC-11 | `OrderTicket` form tests |
| AC-12, AC-13 | repository/HTTP-layer tests against recorded responses |
| AC-14…AC-17 | agent-turn tests over recorded SSE transcripts (§8.3–8.5 are usable as fixtures verbatim) |
| AC-18 | review |

**Test decision:** no backend test is added or changed by this spec — it is
documentation of an already-tested contract. The backend behaviours it
describes are pinned by `tests/unit/api/test_openapi_contract.py`,
`tests/unit/api/test_a2a_examples.py`,
`tests/unit/services/test_a2a_streaming.py`,
`tests/unit/presentation/test_package_boundaries.py`,
`tests/unit/api/test_view_query_options.py` and the `catalog-check` gate step.

## 15. Rollout

None — a document. The `[FE]` subtasks it unblocks are GGU-55, 57, 59, 61, 63,
65 (the six component widgets), GGU-69, 71, 73 (flows A, B and C), GGU-77 (the
catalog gallery) and GGU-79 (the action round-trip).

When a projection changes, `make gate` fails on a stale
`docs/catalog/CONTRACT.md` and the digest in §5.1 moves. **That digest change is
the signal to revisit this document** — specifically §7 and the AC-6 golden
tests.
