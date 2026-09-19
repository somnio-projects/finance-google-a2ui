# Vendor / Third-Party Management

| | |
|---|---|
| **Owner** | Engineering management (contracts) · Security owner (assessment) · **Version** 1.0 — 2026-09-19 · **Next review** 2027-09-19 |
| **Maps to** | SOC 2 CC9.2 · ISO/IEC 27001 A.5.19–A.5.23 |

## 1. Process

1. **Before use** — the requester adds the vendor to the register below and to [CLOUD_SERVICES.md](CLOUD_SERVICES.md) if it is a runtime service; the security owner does the initial review (data class, region, certifications, DPA availability, exit path) and scores the risk (L×I) in the risk register.
2. **Contract** — eng. management executes the DPA / accepts the vendor's data-processing terms; the reference is recorded here. Sub-processor flow-down: we only use vendors that publish their own sub-processor lists.
3. **Annual review** — every September the security owner re-checks certifications (SOC 2 / ISO 27001 reports), sub-processor changes, incidents, and whether the vendor is still needed.
4. **Exit** — removal from CI/config, secret rotation, data deletion request to the vendor, register row moved to "retired".

## 2. Supplier register

| Vendor | Service | Data shared | Class | Certifications (public) | DPA / terms | Initial review | Next review | Risk (R-13) |
|---|---|---|---|---|---|---|---|---|
| Google Cloud (Cloud Run, Cloud SQL, Secret Manager, Logging, Armor) | runtime, database, secrets | Confidential (in DB), Restricted (secrets) | Confidential/Restricted | SOC 1/2/3, ISO 27001/27017/27018 | Google Cloud Data Processing Addendum — **to be accepted in the GCP console when the project is created (GGU-29)**; status: planned, due 2026-10-31 | 2026-09-19 | 2027-09 | low |
| Firebase Auth / Google Identity | OIDC identity provider | user identity (`sub`, email inside tokens) | Confidential | SOC 2, ISO 27001 (Google) | covered by the Google Cloud DPA | 2026-09-19 | 2027-09 | low |
| Google Gemini API | LLM for the agent (future spec) | prompts (Confidential by default), no credentials | Confidential | Google Cloud terms; "Paid services: prompts not used for training" — verify tier at adoption | planned with the agent spec | — | — | to assess |
| Sentry (Functional Software, Inc.) | error telemetry | exception data, `request_id`; **no PII, no bodies** | Internal | SOC 2 Type II, ISO 27001 | Sentry DPA (self-serve, in the org settings) — **to be signed before enabling `SENTRY_DSN` in staging**; due 2026-10-31 | 2026-09-19 | 2027-09 | low |
| GitHub (Microsoft) | source hosting, Actions, Dependabot | public code, CI secrets | Public/Restricted | SOC 1/2, ISO 27001 | GitHub Customer Terms + DPA (org level, Somnio) | 2026-09-19 | 2027-09 | low |
| Anthropic (Claude Code) | AI coding assistant | source code (public), never secrets or user data ([AI_DATA_HANDLING.md](AI_DATA_HANDLING.md)) | Public | SOC 2 Type II, ISO 27001, ISO 42001 | Anthropic Commercial Terms (Somnio account) — no training on API/commercial inputs | 2026-09-19 | 2027-09 | low |
| Aqua Security (Trivy), gitleaks, Semgrep, Astral (uv/ruff), pip-audit | CI tooling (open source / free tier) | source code (public) | Public | n/a (OSS) | OSS licences; Semgrep telemetry disabled (`--metrics=off`) | 2026-09-19 | 2027-09 | low |
| Docker Hub (`postgres:16-alpine`, `python:3.12-slim`) | base images | — | — | n/a | Docker terms | 2026-09-19 | 2027-09 | low (pinned, scanned) |
| Atlassian (Jira), Slack | project tracking, team communication | Internal (tickets, chat); no Confidential data by policy | Internal | SOC 2, ISO 27001 | Somnio company agreements | 2026-09-19 | 2027-09 | low |

## 3. Sub-processor list (what a downstream party would need to know)

For data processed by the finance-google-a2ui backend in production:
**Google Cloud (US, `us-central1`)** — hosting, database, secrets, logs;
**Sentry (US)** — error telemetry without PII. No other party receives
application data. Changes to this list are announced in `CHANGELOG.md`.

## 4. Supply-chain controls (A.5.21)

Pinned lockfiles (`backend/uv.lock`, `client_flutter/pubspec.lock`),
pip-audit + Trivy + Dependabot, SBOM (CycloneDX) generated weekly by the
scheduled scan and stored as a CI artifact, pinned GitHub Actions by major
version, base images pinned by tag and scanned.

## 5. Outsourced development disclosure

None. All development is performed by Somnio staff/contractors
([`CONTRIBUTORS.md`](../../CONTRIBUTORS.md)), with AI assistance governed by
[AI_GOVERNANCE.md](AI_GOVERNANCE.md).
