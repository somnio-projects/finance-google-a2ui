# Data Residency, Tenancy and Encryption

| | |
|---|---|
| **Owner** | Security owner (TL backend) · **Version** 1.0 — 2026-09-19 · **Next review** with the deploy epic (GGU-29) |
| **Maps to** | SOC 2 C1.1, CC6.1, CC6.7 · ISO/IEC 27001 A.8.24, A.5.23 |

## 1. Tenancy — single-tenant by design

The service is **single-tenant**: one deployment serves one program (the
Somnio × Google showcase). There is no `tenant_id`, no row-level security and
no shared-database multi-tenancy — deliberately, because there is one tenant.
User-level isolation is enforced instead: every read of personal history is
keyed by `principal.subject` (ADR-A; `AuditRepository.list_for_subject`,
integration-tested). If a second tenant ever appears, a spec
`specs/backend/NNNN-multi-tenancy.md` must precede any code and this page is
superseded.

## 2. Residency

| Environment | Where data lives | Notes |
|---|---|---|
| Local / demo | the developer's machine (Docker volume) — Argentina/Uruguay team | dev data only; dumps per [BACKUP_AND_RECOVERY.md](BACKUP_AND_RECOVERY.md) |
| Production (planned, ADR-F) | Google Cloud region **`us-central1`** (Cloud Run + Cloud SQL), backups in the same region | chosen to match the Google program's reviewers; change requires updating this page and the vendor register |
| Telemetry | Sentry — US region (org default) | no PII by configuration |
| Identity | Firebase Auth / Google Identity — global service | the API stores only the `sub` |

No data is transferred to other regions by the application. Google's and
Sentry's own subprocessor locations are listed in
[VENDOR_MANAGEMENT.md](VENDOR_MANAGEMENT.md).

## 3. Encryption

| Path | Control |
|---|---|
| In transit, client → API | TLS 1.2+ terminated at the Cloud Run ingress (Google-managed certificates); HSTS `max-age=63072000; includeSubDomains` sent in production; local compose is plain HTTP on `localhost` only |
| In transit, API → PostgreSQL | production: Cloud SQL connector / private IP with TLS; local: Docker network |
| In transit, API → IdP / Sentry | HTTPS only (httpx, sentry-sdk) |
| At rest, database | production: Cloud SQL encryption at rest, Google-managed AES-256 keys (decision: **Google-managed keys are accepted** for the showcase; CMEK to be revisited if client data is ever introduced — recorded in the risk register R-15); local: host disk encryption (FileVault) per DEVICE_POLICY |
| At rest, backups | same as the database they come from |
| Secrets | `SecretStr` in process memory; Secret Manager (encrypted, versioned) in production; `.env` on an encrypted disk locally |
| Tokens | verified with RS256/ES256 (OIDC) or HS256 (service); never stored — SHA-256 fingerprint only |

## 4. Shared responsibility

Google Cloud is responsible for physical security, hardware, network
infrastructure and the managed-service control planes; Somnio is responsible
for configuration (IAM, network exposure, backup settings), application
security and data handling. Details in [CLOUD_SERVICES.md](CLOUD_SERVICES.md).
