# 04 — Lifecycle of one authenticated request

What every `/v1` call goes through. Source of truth: [`backend/docs/SECURITY.md`](../../backend/docs/SECURITY.md), `api/middleware/install.py::install_middleware`.

```mermaid
sequenceDiagram
    autonumber
    participant C as Client
    participant RID as RequestId
    participant SEC as SecurityHeaders
    participant TH as TrustedHost + CORS
    participant BL as BodyLimit
    participant RL as RateLimit
    participant FG as require_feature
    participant AU as AuthService
    participant CD as ConditionalResponse
    participant SV as Service
    participant DB as PostgreSQL

    C->>RID: GET /v1/... + Bearer token
    RID->>RID: mint/echo X-Request-ID, bind to logs
    RID->>SEC:
    SEC->>TH: adds CSP, nosniff, HSTS (prod)
    TH->>BL: host + origin allow-lists
    BL->>RL: 413 if body too large
    RL->>FG: 429 per IP AND per token fingerprint
    FG->>AU: 404 feature-disabled if the flag is off
    AU->>AU: verify signature, iss, aud, exp, iat, sub
    AU-->>C: 401 problem+json if invalid
    AU->>SV: Principal (subject, scopes, amr, fingerprint)
    SV->>SV: authorize by scope (+ MFA for admin in prod)
    %% Provisioning is a second question, asked by the client once per
    %% session: GET /v1/me/access joins the token's email against `users`
    %% (spec 0027) and answers `provisioned` as data — a valid token for an
    %% uninvited person is 200 + false, never a 401.
    SV->>DB: one session per request (commit / rollback)
    SV->>DB: write audit event <domain>.<verb>
    SV->>CD: the DTO, on a read that revalidates
    CD-->>C: 304 (empty) when If-None-Match holds the current ETag
    CD-->>C: DTO + strong ETag + Cache-Control otherwise
    SV-->>C: or an RFC 9457 problem with request_id

    %% ConditionalResponse (api/caching.py) is a dependency, not middleware:
    %% only the routes that opt in revalidate, and the tag is derived from
    %% (resource, view, options, as_of) — ADR-K D-20, spec 0012 AC-7/AC-8.
    %% Every error on /v1/** leaves as application/problem+json; the A2A root answers JSON-RPC error objects instead (ADR-J D-3); no stack traces,
    %% no SQL, no library text ever reaches the caller.
```
