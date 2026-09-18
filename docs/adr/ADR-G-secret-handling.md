# ADR-G — Secret handling in a public repository

- **Status:** Accepted (TL, 2026-09-18)
- **Gates:** GGU-3 (deploy), GGU-12 (credential handover), GGU-45 (CI)

## Context

> **In the context of** a public repo holding a client, a backend and the team's Gemini key,
> **facing** the asymmetry that a leaked key is an unbounded billing and abuse exposure, **we
> decided** that all secrets live in **Google Cloud Secret Manager** and reach the process only as
> injected env, **and neglected** committing an encrypted secrets file or shipping a restricted key
> to the client, **to achieve** a single revocable blast radius, **accepting that** local development
> requires a manual `.env`.

**Verified clean at `410bb9d`:** `backend_python/.env` is untracked, ignored by
`backend_python/.gitignore:2`, and appears in **no commit** in the repository's history. Nothing
needs scrubbing before the repo goes public. `backend_python/.dockerignore` already excludes `.env`,
`.venv`, `.git`, `.claude`.

## Decision

- **D-1** The Gemini key is **backend-only**, held in Secret Manager. The client never holds it and never calls a model API directly.
- **D-2** Secrets reach the process **only** as env vars injected from Secret Manager at deploy. Nothing is baked into the image. `.dockerignore` continues to exclude `.env*` and credential files.
- **D-3** Missing required config is a **startup crash** naming the variable, not a lazy failure. Extend the existing fail-fast to Firebase credentials via `pydantic-settings BaseSettings`.
- **D-4** The `.claude/settings.json` secret-read deny rules MUST NOT be loosened by any ticket.
- **D-5** CI runs a secret scan (gitleaks) on every PR and **fails** the PR on a hit. For a public repo with a live model key this is **required**, not optional.
- **D-6** GGU-12 credentials are delivered out-of-band (password-manager share), never via repo, issue tracker, chat or email; delivery is recorded in the runbook. The credential value itself is never written to the runbook.
- **D-7** A per-uid **rate limit** on the authenticated session endpoint is **required**. Without it, a single compromised provisioned account has unmetered access to the key. This is the compensating control for [ADR-B](ADR-B-auth-credential-contract.md) D-5 (no allow-list).

## Consequences

D-7 is the load-bearing ruling given ADR-B D-5. Access control rests on "one provider, provisioned
accounts only"; the rate limit bounds the damage if one of those accounts is compromised.
