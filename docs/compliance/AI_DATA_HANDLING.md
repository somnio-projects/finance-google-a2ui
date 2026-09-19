# AI Data Handling Statement

| | |
|---|---|
| **Owner** | Security owner (TL backend) · **Version** 1.0 — 2026-09-19 · **Next review** 2027-09-19 or when a model provider/tier changes |
| **Maps to** | SOC 2 P-series (privacy), C1.1 · ISO/IEC 27001 A.8.10, A.8.11, A.5.23 |

## What reaches which AI system

| System | Input | Never sent | Training use |
|---|---|---|---|
| **Claude Code** (development) | public source code, tests, docs, specs, CI output, Somnio CLI audit results, synthetic test data | `.env*` and key files (denied by the harness), real user data, production database dumps, tokens/secrets (also blocked by gitleaks before they can be committed) | Anthropic commercial/API terms: inputs and outputs are **not used to train** Anthropic models |
| **Google Gemini** (product agent, future) | the user's question, tool results (pre-formatted display values), catalog schema | user identifiers, tokens, emails, raw portfolio records beyond what the question needs | paid Google Cloud tier: prompts/responses **not used to train** Google models — the tier is verified and recorded in the vendor register at adoption |
| **Sentry** (not AI, listed for completeness) | exceptions, `request_id` | PII, request bodies (`send_default_pii=False`, `max_request_body_size="never"`) | n/a |

## Client / user data statement

Today the service holds no client data — only pseudonymous identity subjects
and an audit trail. When portfolio data arrives (future specs), it is classified
Confidential and: is **not** used to train or fine-tune any model, first- or
third-party; is sent to the model only as the minimum context for the current
question; is never stored by the model provider beyond the request (zero data
retention or the provider's abuse-monitoring window, documented per vendor).

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
