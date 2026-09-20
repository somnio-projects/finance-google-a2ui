# 07 — Persisted data model

Every table, with the migration that created it. Source of truth: [`backend/alembic/versions/`](../../backend/alembic/versions). Dashed = in review.

```mermaid
erDiagram
    AUDIT_EVENTS {
        uuid id PK
        string subject "IdP sub — Confidential"
        string provider "jwt | oidc"
        string action "<domain>.<verb> — String(64)"
        string target "flag key / resource id — 0003"
        string token_fingerprint "SHA-256 prefix, never the token"
        string request_id "correlates with X-Request-ID"
        datetime created_at "retention 400 days"
    }
    FEATURE_FLAGS {
        string key PK "^[a-z0-9]+(\\.[a-z0-9_-]+)*$"
        bool enabled
        string description
        string updated_by "admin subject"
        datetime created_at
        datetime updated_at
    }
    CONVERSATION_SESSIONS {
        uuid id PK
        string subject "owner — every query is scoped by it"
        string provider
        string title
        datetime created_at
        datetime updated_at
    }
    CONVERSATION_MESSAGES {
        uuid id PK
        uuid session_id FK
        string role "user | assistant | system"
        text content
        datetime created_at
    }
    PORTFOLIOS {
        uuid id PK
        string subject UK "one per subject — uq_portfolios_subject"
        datetime as_of "the seed instant, fixed here not per process"
        datetime created_at
        datetime updated_at
    }
    PORTFOLIO_LOTS {
        uuid id PK
        uuid portfolio_id FK
        string lot_id
        string symbol
        date acquired_on "short/long term boundary"
        decimal quantity "NUMERIC(38,18) — never float"
        decimal cost_basis "NUMERIC(38,18)"
        datetime created_at
    }
    PORTFOLIO_TRANSACTIONS {
        uuid id PK
        uuid portfolio_id FK
        string transaction_id
        date occurred_on
        string kind
        string symbol
        decimal quantity "NUMERIC(38,18)"
        decimal price "NUMERIC(38,18)"
        datetime created_at
    }
    CONVERSATION_SESSIONS ||--o{ CONVERSATION_MESSAGES : "cascade delete"
    PORTFOLIOS ||--o{ PORTFOLIO_LOTS : "the open lots"
    PORTFOLIOS ||--o{ PORTFOLIO_TRANSACTIONS : "the ledger"
```

| Migration | Adds |
|---|---|
| `0001_audit_events` | the audit trail |
| `0002_feature_flags` | runtime endpoint switches |
| `0003_audit_event_target` | `target`, so `action` stays `<domain>.<verb>` in `String(64)` |
| `0004_sessions` *(GGU-46)* | subject-scoped conversations and their messages |
| `0005_portfolios` *(spec [`backend/0020`](../../specs/backend/0020-portfolio-persistence.md))* | the portfolio, its open tax lots and its transaction ledger |

**No holdings table, on purpose.** `Portfolio.positions` is derived from the
lots and `Portfolio.validate` proves the derivation on every load; persisting
it would let a holdings row and its lots drift apart with nothing to catch it
(spec `0020` §3).

The portfolio used to be in process memory, seeded per session — the original
[ADR-F](../adr/ADR-F-persistence-and-session-lifetime.md) D-1/D-2. It moved
here because Cloud Run runs more than one instance: two caches meant one
subject with two `as_of`, and `uq_portfolios_subject` is what makes two
instances seeding a new subject converge on one row. ADR-F D-7 carries the
current ruling.
