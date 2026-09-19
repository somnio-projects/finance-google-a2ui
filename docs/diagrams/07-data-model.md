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
    CONVERSATION_SESSIONS ||--o{ CONVERSATION_MESSAGES : "cascade delete"
```

| Migration | Adds |
|---|---|
| `0001_audit_events` | the audit trail |
| `0002_feature_flags` | runtime endpoint switches |
| `0003_audit_event_target` | `target`, so `action` stays `<domain>.<verb>` in `String(64)` |
| `0004_sessions` *(in review, GGU-46)* | subject-scoped conversations and their messages |

The portfolio domain (GGU-5) is **in-memory and seeded per session** — it is
deliberately not a table ([ADR-F](../adr/ADR-F-persistence-and-session-lifetime.md)).
