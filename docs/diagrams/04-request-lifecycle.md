# 04 — Lifecycle of one authenticated request

What every `/v1` call goes through. Source of truth: [`backend/docs/SECURITY.md`](../../backend/docs/SECURITY.md), `bootstrap.py::_install_middleware`.

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
    SV->>DB: one session per request (commit / rollback)
    SV->>DB: write audit event <domain>.<verb>
    SV-->>C: DTO, or RFC 9457 problem with request_id

    %% Every error leaves as application/problem+json; no stack traces,
    %% no SQL, no library text ever reaches the caller.
```
