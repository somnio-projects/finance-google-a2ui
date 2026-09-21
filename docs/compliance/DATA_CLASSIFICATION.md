# Data Classification and Handling

| | |
|---|---|
| **Owner** | Security owner (TL backend) · **Version** 2.0 — 2026-09-21 · **Next review** 2027-09-19 or when a new data element is stored |
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
| `audit_events` | `provider`, `action`, `target` (flag key / resource id), `request_id`, `created_at` | Internal | no | `action` is `<domain>.<verb>`; `target` never carries PII |
| `audit_events` | `token_fingerprint` | Confidential | no (16-hex SHA-256 prefix) | the token itself is **never** stored |
| `feature_flags` | `key`, `enabled`, `description`, `updated_by` (subject) | Internal (`updated_by` Confidential) | pseudonymous | — |
| `sessions` | `subject` (IdP `sub`) | Confidential | pseudonymous identifier | ownership key; every `SessionRepository` query filters on it |
| `sessions` | `provider`, `title`, `created_at`, `updated_at` | Confidential | `title` is user-supplied free text | `title` bounded at 200 chars; never logged |
| `messages` | `session_id`, `role`, `created_at` | Internal | no | `role` constrained to `user`/`assistant`/`system` by a CHECK constraint |
| `messages` | `content` | **Confidential** | **free text — may contain anything the user types, and is what reaches the model** | bounded by the request body limit; never logged; never sent to Sentry (`max_request_body_size="never"`). Sent to Google Gemini as the turn's prompt — see [AI_DATA_HANDLING.md](AI_DATA_HANDLING.md) |
| `portfolios` | `subject` (IdP `sub`), `as_of` | Confidential | pseudonymous identifier | ownership key, unique per subject (`uq_portfolios_subject`) |
| `portfolio_lots` | `portfolio_id`, `lot_id`, `symbol`, `acquired_on`, `quantity`, `cost_basis` | **Confidential** | financial holdings, indirectly identifying | no subject column — reachable only through the portfolio; cascades with it |
| `portfolio_transactions` | `portfolio_id`, `transaction_id`, `occurred_on`, `kind`, `symbol`, `quantity`, `price`, `amount` | **Confidential** | financial transaction history, indirectly identifying | as above; cascades with the portfolio |
| Token claims (in memory only) | `email` | Confidential / PII | yes | read for the `Principal`, returned to the caller on `/v1/me`, never persisted or logged |
| Logs (structlog) | `request_id`, level, event, error code | Internal | no | `redact_sensitive` drops `authorization`, `token`, `password`, `secret`, `cookie`, `api_key` |
| Sentry | exception type, stack, `request_id`, tags | Internal | no | `send_default_pii=False`, request bodies never sent |

All seven tables the system stores are listed above. The inventory is
enumerated from `backend/src/app/models/`; a table that is not here is either
new or an omission, and the same check applies to `DATA_RETENTION.md` §3.

> **Correction, 2026-09-21.** This section previously ended "Portfolio/finance
> data (future specs) will be classified **Confidential** … before the spec is
> approved". That data is **not future**: `models/portfolio.py:38,48,63` define
> three tables that shipped with spec `backend/0020`, and the conversation
> tables shipped with `backend/0004` before them. Five of the seven tables were
> missing from this inventory. Raised as **NC-6** together with the erasure
> defect it caused — an inventory that does not list a table is why the erasure
> procedure did not delete from it. §3 below claims the `backend-reviewer`
> checks that a new column appears here; on this change it did not fire, which
> is **NC-7**.

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
