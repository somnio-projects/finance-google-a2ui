# Cloud Services, Infrastructure and Monitoring

| | |
|---|---|
| **Owner** | TL backend · **Version** 1.0 — 2026-09-19 · **Next review** when the deploy epic (GGU-29) lands, then annually |
| **Maps to** | SOC 2 CC6.6, CC6.7, CC7.2 · ISO/IEC 27001 A.5.23, A.8.15, A.8.16, A.8.20–A.8.23 |

## 1. Approved services

| Service | Use | Data class sent | Region | Status |
|---|---|---|---|---|
| Google Cloud Run | backend runtime (ADR-F) | Confidential (in process) | `us-central1` | IaC in `infra/` (apply pending GGU-29) |
| Google Cloud SQL for PostgreSQL 16 | database | Confidential | `us-central1` | IaC in `infra/` (apply pending GGU-29) |
| Google Secret Manager | secrets | Restricted | `us-central1` | IaC in `infra/` (apply pending GGU-29) |
| Google Cloud Logging / Monitoring | logs, uptime checks, alerts | Internal | `us-central1` | IaC in `infra/` (apply pending GGU-29) |
| Google Cloud Armor | WAF in front of the load balancer | — | global | IaC in `infra/` (apply pending GGU-29) |
| Firebase Auth / Google Identity | OIDC identity provider | user identity (`sub`, email in token) | global | in use for Epic 0 |
| Google Gemini API | model backing the A2UI agent (future spec) | prompts (Confidential by default), **never** user credentials | US | planned |
| Sentry (SaaS) | error telemetry | Internal (no PII, no bodies) | US | in use when `SENTRY_DSN` set |
| GitHub (Actions, Dependabot, advisories) | source, CI, scanning | Public code, CI secrets (Restricted) | US | in use |
| Docker Hub / GHCR | base images | — | — | in use |

Adding a service = a row here + the vendor register
([VENDOR_MANAGEMENT.md](VENDOR_MANAGEMENT.md)) + the risk register, before use.

## 2. Shared responsibility

| Google / vendor | Somnio |
|---|---|
| physical security, hardware, hypervisor, managed-service control planes, TLS certificates at the managed ingress, OS patching of managed runtimes, NTP | IAM configuration, network exposure, Cloud SQL settings (backups, private IP, HA), secrets, application security, logging configuration, data handling, incident response for the application |

## 3. Production topology (implemented in `infra/` — Terraform, validated; apply pending GGU-29)

- **Network**: Cloud SQL on **private IP** only; Cloud Run egress through a Serverless VPC connector; ingress "internal and Cloud Load Balancing"; Cloud Armor policy with the OWASP preconfigured rule set and per-IP rate limiting in front of the app-layer limiter.
- **Identity**: one Cloud Run service account with `cloudsql.client` + `secretmanager.secretAccessor` + `logging.logWriter` only; no human `owner`; humans `viewer` with time-boxed break-glass ([ACCESS_CONTROL.md](ACCESS_CONTROL.md) §4).
- **Secrets**: Secret Manager, one secret per setting, versioned, **90-day rotation** with Cloud Scheduler reminder; injected as env vars.
- **Redundancy**: Cloud SQL HA (regional), Cloud Run min-instances ≥ 1, multi-zone by default; uptime check on `/readyz`.
- **Backups**: automated daily + PITR, 30-day retention ([BACKUP_AND_RECOVERY.md](BACKUP_AND_RECOVERY.md)).
- **IaC**: Terraform in [`infra/`](../../infra/README.md) with `environments/staging.tfvars` and `production.tfvars`; `.github/workflows/infra-ci.yaml` runs `fmt`, `validate` and `trivy config` (misconfiguration rules) on every change.

**State:** the code above is committed and validated but **not applied** — no
GCP project exists yet (GGU-29). Until the first apply the only running
topology is the local `docker-compose.yml` (dev only, `localhost`), and the
retained risk R-11 applies.

## 4. Logging

| Log | Content | Retention |
|---|---|---|
| Application (structlog JSON to stdout → Cloud Logging) | level, event, `request_id`, error codes; **no tokens, no PII** (`redact_sensitive`) | **90 days** (log bucket retention set in IaC) |
| Audit trail (`audit_events` table) | subject, provider, action, token fingerprint, request id | 400 days ([DATA_RETENTION.md](DATA_RETENTION.md)) |
| Cloud Audit Logs (Admin Activity + Data Access for Cloud SQL and Secret Manager) | control-plane actions by humans and service accounts | 400 days (Admin Activity default) / 90 days |
| Load balancer + VPC flow logs | edge/network access | 30 days |
| CI logs and artifacts (coverage, SBOM, SARIF) | build evidence | 90 days |

Log access is read-only for engineers; export for incidents follows the IR
plan §5.

## 5. Monitoring and alerting

| Signal | Source | Alert → channel |
|---|---|---|
| Unhandled exceptions, error-rate spike | Sentry (`SENTRY_DSN` set in staging/production; alert rule "≥ 10 events / 5 min") | Slack `#finance-google-a2ui-dev` + on-call |
| Auth failures spike (`auth.rejected` counter) | Sentry metrics / Cloud Monitoring log-based metric on `auth/*` error codes | Slack + on-call (possible credential stuffing) |
| Readiness | Cloud Monitoring uptime check on `/readyz` every 60 s, 3 failures | Slack + on-call |
| 5xx ratio, latency p95 | Cloud Run metrics | Slack |
| Backup failure | Cloud SQL operation alert | Slack + TL backend |
| Feature-flag toggles | `feature_flag.toggled` metric + audit rows | dashboard (no alert) |
| Secret rotation due | Cloud Scheduler reminder | TL backend |

On-call: the security owner by default, backup the backend engineer
([INCIDENT_RESPONSE_PLAN.md](INCIDENT_RESPONSE_PLAN.md) §2). Alerts feed the
IR plan; every SEV-1/2 alert creates an incident issue.

## 6. Egress allow-list (what the backend talks to)

PostgreSQL (private), the OIDC issuer's JWKS URL (`AUTH_OIDC_JWKS_URL`),
Sentry ingest, Gemini API (future). Anything else is a finding.
