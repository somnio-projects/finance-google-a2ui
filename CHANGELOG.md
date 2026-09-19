# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versions follow
[Semantic Versioning](https://semver.org/) and are the `backend/pyproject.toml`
version reported by `GET /healthz`. Sub-processor changes are announced here
too (`docs/compliance/VENDOR_MANAGEMENT.md` §3).

## [Unreleased]

### Added
- Backend foundation in `backend/`: layered FastAPI service, bearer-token auth with pluggable `jwt`/`oidc` verifiers, audit trail, RFC 9457 errors, HTTP hardening middleware, Sentry behind an `ErrorReporter` protocol, PostgreSQL via SQLAlchemy async + Alembic, 100 % branch-coverage gate (spec 0001).
- Runtime feature flags: `require_feature()` gate, admin API, env kill-switch, TTL cache (spec 0002).
- Audit-trail retention purge (`AuditRepository.purge_older_than`, `make purge-audit`, `AUDIT_RETENTION_DAYS`).
- MFA requirement for admin operations via the `amr` claim (`AUTH_ADMIN_REQUIRE_MFA`, on by default in production).
- Docker image (non-root, read-only) and root `docker-compose.yml` (db + backend, env from `backend/.env`).
- Claude Code harness (codelab 2): rules, hooks, commands, `backend-reviewer` agent, ship gate, specs, harness log.
- CI: ship gate, gitleaks, Semgrep SAST, image build with Trivy; weekly scheduled scan with SBOM; Dependabot; pre-commit.
- `infra/`: Terraform for the Google Cloud production topology (private VPC, Cloud SQL 16 regional HA + PITR, Secret Manager with 90-day rotation, least-privilege IAM, Cloud Run service + purge job, HTTPS LB with Cloud Armor, 90-day log retention, audit logs, alerts) with `infra-ci.yaml` (fmt, validate, trivy config). Validated, not applied (GGU-29).
- Continuous delivery for the backend (spec 0007, GGU-48): `backend-cd.yaml` builds and pushes the image to Artifact Registry by digest, deploys the Cloud Run revision with no traffic, verifies `/readyz`, shifts traffic, verifies `/healthz`, and rolls back automatically if any step fails. `develop` releases staging unattended; `main` releases production behind a required reviewer. Authentication is Workload Identity Federation — no service-account key.
- `GET /healthz` now reports the release identifier `<version>+<short sha>` (`APP_RELEASE`), falling back to the packaged version locally.
- `infra/delivery.tf`: Artifact Registry repository with retention policies, the Workload Identity pool and provider pinned to this repository, and a least-privilege deployer service account.
- Tested delivery scripts: `infra/scripts/deploy_cloud_run.sh` with behaviour tests against a stub `gcloud` (including the rollback path) and a guard that fails the build if a long-lived key appears. Both run in pre-commit and in `infra-ci`.
- Compliance corpus under `docs/compliance/` (SOC 2 / ISO 27001 policies, ISMS artifacts, runbooks, first restore drill), `SECURITY.md`, `CODE_OF_CONDUCT.md`, `CONTRIBUTORS.md`, `.github/CODEOWNERS`, PR template.

### Removed
- Inherited Google ADK sample `backend_python/`.
