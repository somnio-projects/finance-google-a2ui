# Data Classification and Handling

| | |
|---|---|
| **Owner** | Security owner (TL backend) · **Version** 1.0 — 2026-09-19 · **Next review** 2027-09-19 or when a new data element is stored |
| **Maps to** | SOC 2 C1.1, C1.2, P-series · ISO/IEC 27001 A.5.12, A.5.13, A.8.10, A.8.11 |

## 1. Classes

| Class | Definition | Examples here | Handling |
|---|---|---|---|
| **Public** | intended for anyone | source code, docs, specs, this policy set, OpenAPI (non-prod) | none |
| **Internal** | Somnio/team only; low harm if disclosed | feature-flag state, non-sensitive logs, Sentry events (no PII), Jira tickets | Slack/Jira/GitHub private surfaces; no external sharing without PM approval |
| **Confidential** | harm to users or the program if disclosed | `audit_events` (subject, provider, action, token fingerprint, request id), user email when present in a token, Google program material, incident evidence | encrypted at rest and in transit; access by role; never in logs, tests or chat; retention per [DATA_RETENTION.md](DATA_RETENTION.md) |
| **Restricted** | direct security impact | `AUTH_JWT_SECRET`, OIDC/IdP credentials, model API key, Sentry DSN, CI/deploy credentials, backups containing Confidential data | `SecretStr` only; `.env`/Secret Manager; never committed, printed or pasted; rotation per [ACCESS_CONTROL.md](ACCESS_CONTROL.md) §3 |

## 2. Field inventory (what the system stores today)

| Store | Field | Class | PII? | Minimisation applied |
|---|---|---|---|---|
| `audit_events` | `subject` (IdP `sub`) | Confidential | pseudonymous identifier | stored as given by the IdP; no name/email |
| `audit_events` | `provider`, `action`, `request_id`, `created_at` | Internal | no | — |
| `audit_events` | `token_fingerprint` | Confidential | no (16-hex SHA-256 prefix) | the token itself is **never** stored |
| `feature_flags` | `key`, `enabled`, `description`, `updated_by` (subject) | Internal (`updated_by` Confidential) | pseudonymous | — |
| Token claims (in memory only) | `email` | Confidential / PII | yes | read for the `Principal`, returned to the caller on `/v1/me`, never persisted or logged |
| Logs (structlog) | `request_id`, level, event, error code | Internal | no | `redact_sensitive` drops `authorization`, `token`, `password`, `secret`, `cookie`, `api_key` |
| Sentry | exception type, stack, `request_id`, tags | Internal | no | `send_default_pii=False`, request bodies never sent |

Portfolio/finance data (future specs) will be classified **Confidential** by
default and added here with its minimisation before the spec is approved
(spec template §5 "Security notes").

## 3. Labelling

Classification is expressed in code, not in prose: `SecretStr` for Restricted
settings; pydantic DTO docstrings state the class for Confidential fields;
tables list their classes in this inventory. The `backend-reviewer` checks
that a new column or DTO field appears here.

## 4. Handling rules by activity

| Activity | Public | Internal | Confidential | Restricted |
|---|---|---|---|---|
| Store in git | yes | no (except non-sensitive config) | never | never |
| Log | yes | yes | never (use ids/fingerprints) | never |
| Send to Sentry | yes | yes | never | never |
| Paste into AI assistant | yes | with care | never | never |
| Share with Google program | yes | with PM approval | only through agreed channels | never |
| Backups | n/a | included | included, encrypted, restricted | excluded by design |
| Disposal | n/a | delete when obsolete | purge per retention; secure delete of dumps | rotate then delete |
