# AI Data Handling Statement

| | |
|---|---|
| **Owner** | Security owner (TL backend) · **Version** 2.0 — 2026-09-21 · **Next review** 2027-09-19 or when a model provider/tier changes |
| **Maps to** | SOC 2 P-series (privacy), C1.1 · ISO/IEC 27001 A.8.10, A.8.11, A.5.23 |

## What reaches which AI system

| System | Input | Never sent | Training use |
|---|---|---|---|
| **Claude Code** (development) | public source code, tests, docs, specs, CI output, Somnio CLI audit results, synthetic test data | `.env*` and key files (denied by the harness), real user data, production database dumps, tokens/secrets (also blocked by gitleaks before they can be committed) | Anthropic commercial/API terms: inputs and outputs are **not used to train** Anthropic models |
| **Google Gemini** (product agent — **LIVE**, default `gemini-3.8-flash`) | the user's question (`messages.content`, free text), tool results as pre-formatted `*Display` strings, and the generated system prompt (tool + view catalogs) | user identifiers (`sub`), tokens, emails, the API key (header only, never a query string) — none of these enter the payload (`infra/model/payload.py`) | **Not verified — assume free-tier terms.** The paid tier excludes training, but the tier has not been confirmed for this project. Gap **G-VEN-1**, owner eng. management, due 2026-10-31 ([VENDOR_MANAGEMENT.md](VENDOR_MANAGEMENT.md) §2a) |
| **Sentry** (not AI, listed for completeness) | exceptions, `request_id` | PII, request bodies (`send_default_pii=False`, `max_request_body_size="never"`) | n/a |

## Client / user data statement

The service holds **no real client data**: every portfolio is synthetic seed
data and every identity is a demo or reviewer account. That is the control
that bounds everything below, and it is a condition, not an observation —
entering real client data invalidates this statement.

What the service does now hold, all classified Confidential in
[DATA_CLASSIFICATION.md](DATA_CLASSIFICATION.md) §2: pseudonymous identity
subjects, an audit trail, conversation sessions and their free-text messages,
and synthetic portfolios with their lots and transactions.

Of these, two reach the model: the user's **question** and **tool results**
(pre-formatted display values). Portfolio rows are never sent verbatim — the
model receives the figures a tool already formatted, which is the same
invariant that stops it computing them.

> **Correction, 2026-09-21.** This section previously read "Today the service
> holds no client data … When portfolio data arrives (future specs)". The
> portfolio tables shipped with spec `backend/0020` and the conversation
> tables with `backend/0004`; the agent that sends their derived figures to
> Gemini shipped with `0006`/`0009`/`0010`. The sentence describing all of it
> as future was wrong on the day the audit ran. Raised as **NC-6**.

Two claims this statement previously made that it **cannot** currently make:

- **"Not used to train."** True only on the paid tier, which is unverified —
  gap **G-VEN-1**. Until it is closed, assume free-tier terms.
- **"Never stored beyond the request."** We have no zero-data-retention
  agreement with Google for the Gemini API and no evidence of the
  abuse-monitoring window that applies. Gap **G-AI-1**, owner security owner,
  due 2026-10-31, closed by the same tier confirmation.

## PII controls that make the statement true

- Tokens are fingerprinted (SHA-256 prefix), never stored or logged (`helpers/tokens.py`).
- Logs pass through `redact_sensitive`; problem responses carry no internals.
- Emails from tokens live only in the request's `Principal`; they are not persisted.
- The harness denies the agent access to secret files; commits are scanned by gitleaks.
- Retention and erasure follow [DATA_RETENTION.md](DATA_RETENTION.md).

## Contributor rules

Do not paste Confidential/Restricted data ([DATA_CLASSIFICATION.md](DATA_CLASSIFICATION.md))
into any AI assistant, including error messages that contain tokens or real
identifiers — redact first. Synthetic data only in prompts, tests and specs.
