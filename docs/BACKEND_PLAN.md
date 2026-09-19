# Backend plan — ownership, order and open tickets

**Baseline:** PR #2 (the `backend/` FastAPI foundation) is merged; `develop` is
the integration branch. Demo target **2026-09-28**.
**Owners:** Lautaro (TL, with Claude) · Mario Campbell (`@mcampbell-somnio`).

The split is deliberate: Lautaro+Claude own the **critical path and everything
shared** (domain, transport, agent host, session/auth, deploy); Mario owns
**three leaf tickets that touch no shared file**, so neither side ever waits on
the other or resolves a conflict.

## 1. Where every backend ticket stands after PR #2

| Ticket | Scope | State | Owner |
|---|---|---|---|
| **GGU-45** Backend dev tooling + CI | ship gate, pre-commit, CI | **Done** — delivered by PR #2 (gate = pre-commit = CI, quality suite, image + CVE scan) | — (close it) |
| **GGU-3** Service skeleton + streaming transport | A2A/A2UI streaming surface | **Re-baseline**: the hardening half (health, fail-fast config, CORS/hosts, container, Cloud Run readiness) is **done** in `backend/`; the **streaming transport is net-new** — the ADK sample it described was deleted | Lautaro+Claude |
| **GGU-46** Firebase ID tokens + session identity | auth middleware, uid binding | **Half done**: OIDC/JWKS verification, `Principal`, scopes, per-token rate limit, audit trail shipped; **binding a session to the verified subject** is pending because sessions do not exist yet | Lautaro+Claude |
| **GGU-5** Domain model (holdings, tax lots, transactions, pricing) | pure module + seed | Net-new. Contract drafted in `docs/specs/GGU-5/domain-contract.md` | Lautaro+Claude |
| **GGU-36** `compute_attribution()` | Flow A data | Net-new; also settles the open `price_series` window question in the GGU-5 contract | Lautaro+Claude |
| **GGU-39** `get_holdings()` | holdings + allocation | Net-new, pure | **Mario** |
| **GGU-38** `payoff()` | risk/payoff curve | Net-new, pure | **Mario** |
| **GGU-37** `simulate_sale()` | tax-lot walk, FIFO/LIFO/HIFO | Net-new, pure | **Mario** |
| **GGU-14** System-prompt fragments | teaching the model the catalog | Blocked on the frozen catalog schemas (GGU-41) | Lautaro+Claude |
| **GGU-29** Deployment | Cloud Run + hosting | IaC **written and validated** in `infra/`; apply pending (GCP project, DNS, Artifact Registry) | Lautaro+Claude |
| **GGU-12** Google demo account | provisioning | Ops, unblocked by auth | Lautaro |
| **GGU-28** OSS hygiene | README, architecture, licence | Largely done by PR #2 (`README`, `CLAUDE.md`, `docs/`, Apache-2.0, `SECURITY.md`, `CONTRIBUTORS.md`) — needs a final pass | Lautaro+Claude |

## 2. Order of work

**Wave 1 — unblock everyone (Lautaro+Claude, day 1)**

1. **Re-baseline the tickets** (every `[BE]` ticket still says *repo `backend_python/`*, which no longer exists) — one comment per ticket + updated header.
2. **GGU-5 domain module** (spec `0003`): `Decimal` money, holdings / tax lots / transactions / price series, invariants that can fail, deterministic seed, injected clock. **Pure, no HTTP.** This is the contract Mario's three tickets compile against, so it ships first and is frozen the moment it merges.
3. **Tool seam**: a `ToolRegistry` + one `deps.py` provider, so every deterministic tool registers itself in **its own module** — nobody edits a shared file to add a tool (this is what makes Mario's PRs conflict-free).

**Wave 2 — parallel, no overlap**

| Lautaro + Claude | Mario |
|---|---|
| **GGU-3** streaming transport + agent host (see open decision below) | **GGU-39** `get_holdings()` |
| **GGU-46** session persistence + isolation by subject | **GGU-38** `payoff()` |
| **GGU-36** `compute_attribution()` (Flow A) | **GGU-37** `simulate_sale()` |

**Wave 3 — integration**

- **GGU-14** prompt fragments once GGU-41 freezes the schemas; flows GGU-23/24/25 with Pato and Timur.
- **GGU-29**: create the GCP project, apply `infra/`, wire the CD workflow, run a restore drill against Cloud SQL.
- **GGU-12** demo account; **GGU-28** final OSS pass.

## 3. Rules for every ticket (no exceptions)

Spec first under `specs/backend/NNNN-*.md` → branch off `develop` → layered
implementation (controller → service → repository → model) → **strictly RESTful
paths with exhaustive OpenAPI** (`.claude/rules/backend/api-design.md`) →
`make gate` green (100 % branch coverage, code-smell suite) → `backend-reviewer`
→ PR to `develop` → harness-log entry.

## 4. Tickets that are missing (proposed)

1. **Agent host + Gemini adapter** — nothing covers "the LLM adapter, tool registry and turn loop inside the new layering". GGU-14 is only the prompt text. **Blocks every flow.**
2. **Session & conversation persistence** — the ADK `InMemorySessionService` went away with the sample; with PostgreSQL we need `sessions`/`messages` persisted and isolated by subject. GGU-46 assumed ADK sessions and cannot close without this.
3. **Client-facing API contract for the flows** — which surface the Flutter client calls (see the open decision), its error semantics and its streaming format; `docs/specs/GGU-3/api-contract.md` documents the *old* A2A surface.
4. **CD pipeline** — build → push to Artifact Registry → deploy Cloud Run (GGU-29 covers the infrastructure, not the pipeline).
5. **Re-baseline / close GGU-45** and correct the repo pointer in GGU-3/5/36/37/38/39/46.

## 5. Open decision to settle before Wave 2 — REST vs the A2A protocol

The project rule is **everything RESTful and fully documented in OpenAPI**. The
A2A/A2UI protocol, however, is an *external* contract: JSON-RPC `message/stream`
POSTed to the service root, with the agent card at
`/.well-known/agent-card.json`. Those two cannot both be true for the same
surface.

**Proposal:** keep them separate and say so in an ADR.

- `/v1/**` — our own API: strictly RESTful, exhaustively documented, the rule applies in full.
- `/` + `/.well-known/agent-card.json` — the A2A protocol surface, implemented to Google's spec, documented in OpenAPI as a single operation with its JSON-RPC envelope described. It is an adapter over the same services, not a second architecture.

Needs Lautaro's call (and a note to Pato, since the Flutter client consumes both).
