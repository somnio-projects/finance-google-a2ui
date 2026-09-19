# AI Governance Policy

| | |
|---|---|
| **Owner** | Security owner (TL backend) · **Approved by** engineering management · **Version** 1.0 — 2026-09-19 · **Next review** 2027-09-19 |
| **Maps to** | SOC 2 CC1.x, CC2.x, CC4.x · ISO/IEC 27001 A.5.1, A.8.29 · ISO/IEC 42001 (reference) |

## 1. Where AI is used

| Use | System | Scope | Human gate |
|---|---|---|---|
| **AI-assisted development** | Claude Code (Anthropic) inside the repository harness (`.claude/`) | writing code, tests, docs, specs; running the gate; read-only review (`backend-reviewer` agent); Somnio CLI audits | spec approval → ship gate → reviewer agent → **human PR review by a code owner** → merge |
| **Product AI** (the showcase itself) | Google Gemini via the A2UI agent (future spec) | answers portfolio questions by composing UI components | product invariant **"numbers-from-tools"**: the model never computes financial figures; deterministic backend tools return pre-formatted values the model copies (root `CLAUDE.md`) |

No AI system makes an autonomous decision that affects a user's data or
access. No AI system has production credentials.

## 2. Development-time controls

- **Scope of authority** — the agent works inside `.claude/settings.json` permissions: it cannot read `.env*` or key files, cannot edit merged migrations or `uv.lock`, cannot lower gate thresholds. Bash runs sandboxed by default.
- **Specs first** — no feature without an approved `specs/backend/NNNN-*.md`; the human approves the contract before code exists (`.claude/rules/backend/sdd.md`).
- **Automated assurance** — 100 % branch coverage, strict typing, ruff `S`, Semgrep, gitleaks, pip-audit, Trivy; the PostToolUse hook re-checks every edited file.
- **Independent review** — the `backend-reviewer` agent (read-only, runs the gate, checks layering/security/spec traceability) before every PR; then a **human** code owner reviews and merges. AI output is never merged without a human approval.
- **Accuracy and bias review** — reviewers check that generated tests assert behaviour (not just execute lines), that error paths are covered, that names/docs reflect what the code does, and that no assumption about users (locale, name format, gender) is hard-coded. Findings are treated like any review finding.
- **Audit trail** — every iteration is recorded in `.claude/harness-log.md` (what changed in code and in the harness, what the next person must know); commits carry no AI attribution by team decision but the log and the PR describe the agent's involvement. Session transcripts are kept by the operator for 90 days.
- **Rules are versioned** — `.claude/rules/**`, hooks and commands change through PRs like code; synced rule packs come from `somnio-ai-tools` with the revision recorded in `.claude/harness.json`.

## 3. Product-time controls (for the agent, when it lands)

- Model access only through a backend adapter holding the key as `SecretStr`; the client never sees the key.
- Prompts contain the minimum context; user identifiers are never sent to the model; outputs are validated against the A2UI catalog schema before rendering.
- Every model interaction is logged with `request_id` (no prompt bodies in logs); rate-limited per principal; disable-able with a feature flag.
- Human review of prompt/catalog changes through the same PR process; an evaluation set of golden questions runs in CI when the agent spec lands.

## 4. Data handling

See [AI_DATA_HANDLING.md](AI_DATA_HANDLING.md): no secrets, tokens or real
user data are provided to any AI system; Anthropic commercial terms and Google
paid-tier terms exclude training on our inputs.

## 5. Accountability

The security owner owns this policy; engineering management approves it; every
contributor attests to §2 rules in the security primer. Incidents caused by
AI-generated changes follow the standard incident and postmortem process, with
"AI-assisted" recorded as a factor so patterns can be tracked in the management
review.
