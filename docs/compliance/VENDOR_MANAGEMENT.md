# Vendor / Third-Party Management

| | |
|---|---|
| **Owner** | Engineering management (contracts) · Security owner (assessment) · **Version** 2.0 — 2026-09-21 · **Next review** 2027-09-19 |
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
| Google Gemini API (`generateContent`, default model `gemini-3.8-flash`) | **LIVE** — the model behind the A2UI agent (specs `backend/0006`, `0009`, `0010`; `infra/model/gemini_client.py`) | Per turn: the generated system prompt (tool + view catalogs, no user data), the user's question (`messages.content`, free text), and tool results as pre-formatted `*Display` strings. **Never** the bearer token, the `sub`, the email claim, or any credential — the API key is `SecretStr` and becomes a header, never a query string | Confidential | Google Cloud terms; "Paid services: prompts not used for training" — **tier not yet verified, see the gap below** | **2026-09-21** | 2027-09 | **medium — see R-13 and the gap below** |
| Sentry (Functional Software, Inc.) | error telemetry | exception data, `request_id`; **no PII, no bodies** | Internal | SOC 2 Type II, ISO 27001 | Sentry DPA (self-serve, in the org settings) — **to be signed before enabling `SENTRY_DSN` in staging**; due 2026-10-31 | 2026-09-19 | 2027-09 | low |
| GitHub (Microsoft) | source hosting, Actions, Dependabot | public code, CI secrets | Public/Restricted | SOC 1/2, ISO 27001 | GitHub Customer Terms + DPA (org level, Somnio) | 2026-09-19 | 2027-09 | low |
| Anthropic (Claude Code) | AI coding assistant | source code (public), never secrets or user data ([AI_DATA_HANDLING.md](AI_DATA_HANDLING.md)) | Public | SOC 2 Type II, ISO 27001, ISO 42001 | Anthropic Commercial Terms (Somnio account) — no training on API/commercial inputs | 2026-09-19 | 2027-09 | low |
| Aqua Security (Trivy), gitleaks, Semgrep, Astral (uv/ruff), pip-audit | CI tooling (open source / free tier) | source code (public) | Public | n/a (OSS) | OSS licences; Semgrep telemetry disabled (`--metrics=off`) | 2026-09-19 | 2027-09 | low |
| Docker Hub (`postgres:16-alpine`, `python:3.12-slim`) | base images | — | — | n/a | Docker terms | 2026-09-19 | 2027-09 | low (pinned, scanned) |
| Atlassian (Jira), Slack | project tracking, team communication | Internal (tickets, chat); no Confidential data by policy | Internal | SOC 2, ISO 27001 | Somnio company agreements | 2026-09-19 | 2027-09 | low |

### 2a. Gemini — initial review, 2026-09-21

The review §1 step 1 requires, completed against the merged code rather than
against the spec that proposed it.

| Question | Answer | Evidence |
|---|---|---|
| Is it in use? | **Yes.** It has been live since specs `backend/0006`/`0009`/`0010` merged. An unset `GEMINI_API_KEY` falls back to the deterministic `ScriptedModelClient`, so absence of a key is not absence of the vendor | `backend/src/app/infra/model/gemini_client.py`, `bootstrap.py` |
| What data class reaches it? | **Confidential** — `messages.content` is user free text, now classified in [DATA_CLASSIFICATION.md](DATA_CLASSIFICATION.md) §2 | `models/conversation_message.py` |
| Does it receive identifiers? | **No.** The prompt carries the question and tool results; the `sub`, the email claim and the token never enter the payload | `infra/model/payload.py`, `services/prompt_service.py` |
| Is the key protected? | **Yes.** `SecretStr`, `get_secret_value()` called in exactly one function, on the way into a header — asserted by a boundary test over the parsed source | `gemini_client.py` |
| Region | US | `gemini_base_url` default |
| Exit path | Unset `GEMINI_API_KEY`; the agent degrades to the scripted `ScriptedModelClient` rather than failing. The `agent.a2a` flag switches the surface off outright | `api/a2a.py`, `infra/model/scripted_client.py` |

**Open gap (G-VEN-1) — the paid-tier training exclusion is not verified ·
Owner: eng. management · Due 2026-10-31.**

The register has said "verify tier at adoption" since 2026-09-19. Adoption has
happened and **the verification has not been done**. It cannot be done from
inside this repository: whether the Google Cloud project's Gemini usage is on
the paid tier — and therefore whether "prompts not used for training" applies
— is a fact about the billing account, evidenced by a console screenshot or a
billing export, not by any file here. Until that evidence is recorded in this
row, we must assume the **free-tier terms**, under which prompts **may** be
used to improve Google's products.

Consequences we are accepting until it is closed, deliberately:

- Only **synthetic portfolio data** and demo accounts reach the agent. No real
  client data is entered into a conversation before this gap closes.
- The Google Cloud DPA (row 1, also due 2026-10-31) covers Cloud Run, Cloud SQL
  and Secret Manager. Whether it extends to the Gemini API depends on the same
  tier question, so the two close together.

**Risk register:** carried under R-13 (vendor data handling). Raised from
"to assess" to **medium** because a live vendor receiving Confidential free
text under unconfirmed training terms is a real, currently-held exposure, not
a theoretical one.

## 3. Sub-processor list (what a downstream party would need to know)

For data processed by the finance-google-a2ui backend in production:
**Google Cloud (US, `us-central1`)** — hosting, database, secrets, logs;
**Sentry (US)** — error telemetry without PII. No other party receives
application data. Changes to this list are announced in `CHANGELOG.md`.

## 4. Supply-chain controls (A.5.21)

Pinned lockfiles (`backend/uv.lock`, `frontend/pubspec.lock`),
pip-audit + Trivy + Dependabot, SBOM (CycloneDX) generated weekly by the
scheduled scan and stored as a CI artifact, pinned GitHub Actions by major
version, base images pinned by tag and scanned.

## 5. Outsourced development disclosure

None. All development is performed by Somnio staff/contractors
([`CONTRIBUTORS.md`](../../CONTRIBUTORS.md)), with AI assistance governed by
[AI_GOVERNANCE.md](AI_GOVERNANCE.md).
