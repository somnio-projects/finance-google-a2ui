# Access Control Policy

| | |
|---|---|
| **Owner** | Security owner (TL backend) · **Version** 1.1 — 2026-09-21 · **Next review** 2027-09-19 |
| **Maps to** | SOC 2 CC6.1, CC6.2, CC6.3, CC6.6 · ISO/IEC 27001 A.5.15, A.5.17, A.5.18, A.8.2, A.8.5 |

## 1. Principles

Least privilege · deny by default · every access decision in code is tested
· every privileged action is audited · identities are unique (no shared
accounts; service tokens carry their own `sub`).

## 2. API access model

| Layer | Rule | Where |
|---|---|---|
| Authentication | Bearer token on every route except `/health`, `/readyz`, `/openapi.json`, `/docs` | `api/deps.py::get_current_principal` |
| Token verification | signature, `iss`, `aud`, `exp`, `iat`, `sub` required; leeway ≤ 300 s | `auth/providers/*`, `core/config.py` |
| Providers | `oidc` (RS256/ES256 via JWKS — Firebase/Google/any SSO) for users; `jwt` (HS256 shared secret) for service-to-service and local dev only | `auth/registry.py` |
| Authorization | scopes from `scope` / `scp` / `roles` claims, lower-cased; decisions in services via `principal.has_scope()` | `core/principal.py`, services |
| Privileged operations | scope `admin`; **in production admin also requires MFA** — the token's `amr` claim must contain an MFA method (`mfa`, `otp`, `hwk`, `swk`, `sms`, `fido`) — `AUTH_ADMIN_REQUIRE_MFA` (default `true` when `ENVIRONMENT=production`) | `services/feature_flag_service.py::_require_admin`, `core/principal.py` |
| Audit | identity reads and every admin action recorded with subject, provider, action, token fingerprint, request id | `services/audit_service.py` |

### Scope matrix

| Scope | Grants | Who holds it |
|---|---|---|
| (authenticated, no scope) | `GET /v1/me`, `GET /v1/me/audit-events` (own history only) | every signed-in user |
| `admin` | `GET/PUT /v1/admin/feature-flags` | TL backend, on-call engineer; issued by the IdP group `finance-a2ui-admins` (production) or minted locally with the dev secret |

New scopes are added to this table in the same PR that introduces them.

## 3. Token lifetime, revocation, secrets

- **Lifetime**: user tokens ≤ 1 h (IdP setting); service tokens ≤ 10 min, minted per job. The API rejects anything past `exp` + leeway.
- **Revocation**: the API is stateless by design; revoke at the IdP (session/refresh revocation) — takes effect at the next token expiry (≤ 1 h). For HS256 service tokens, rotating `AUTH_JWT_SECRET` invalidates all of them immediately; that is the break-glass revocation. **This latency is an accepted residual risk, not an implementation gap to be closed** — [ADR-B](../adr/ADR-B-auth-credential-contract.md) D-12 and the gap row in [`backend/docs/SECURITY.md`](../../backend/docs/SECURITY.md) carry the reasoning and the owner. Concretely, during that window the revoked token is **accepted with a 200**; it is not rejected early, because a stateless verifier has nothing to consult. Offboarding and incident playbooks must assume the wait (GGU-87).
- **Password / MFA standards**: delegated to the OIDC IdP (Firebase/Google): minimum 12 characters or passkeys, breached-password check, MFA required for the admin group, lockout after repeated failures. The API never handles passwords.
- **`AUTH_JWT_SECRET`**: ≥ 32 random bytes (PyJWT warns below); rotated every **90 days** and on any suspicion or leaver event ([ONBOARDING_OFFBOARDING.md](ONBOARDING_OFFBOARDING.md)); stored only in `.env` (local) / Secret Manager (production).
- **Model key, Sentry DSN**: same 90-day rotation; owner TL backend; rotation recorded in the access-review table.

## 4. Repository and platform access

| System | Roles | Rule |
|---|---|---|
| GitHub | `admin`: eng. management; `write`: engineers; `triage`: PM/UX | org-enforced 2FA; **active** ruleset on `main` and `develop` — PR + 1 code-owner approval + resolved threads, squash-only, no force-push ([CHANGE_MANAGEMENT.md](CHANGE_MANAGEMENT.md)) |
| Google Cloud (when production exists) | `roles/run.developer`, `roles/cloudsql.client`, `roles/secretmanager.secretAccessor` per service account; humans get `viewer` + break-glass `editor` via time-boxed grant | no `owner` on the project; IAM in `infra/iam.tf` (apply with GGU-29) |
| Sentry | project member | PII disabled at the SDK |
| Secrets | Secret Manager accessor bound to the Cloud Run service account only | humans read secrets only during an incident, logged |

## 5. Provisioning workflow

Requests and removals go through the access issue in
[ONBOARDING_OFFBOARDING.md](ONBOARDING_OFFBOARDING.md); `admin`-scope grants
in production are IdP group changes approved by the security owner and noted in
the same issue.

## 6. Access review (quarterly)

The security owner reviews: GitHub collaborators and roles, IdP admin group,
GCP IAM (when present), Sentry members, CODEOWNERS, open access issues,
secret rotation dates. Findings → removals within 2 business days; record below.

| Quarter | Date | Reviewer | Systems | Findings / actions |
|---|---|---|---|---|
| 2026-Q3 | 2026-09-19 | Security owner | GitHub (`lautarob`, `mcampbell-somnio`, `pburzaco-somnio`, `ghilal-somnio`, `tinted-knight`), Slack, Jira | baseline recorded; no production IAM yet; `AUTH_JWT_SECRET` rotation clock starts at first deploy |
| 2026-Q4 | due 2026-12-19 | | | |
