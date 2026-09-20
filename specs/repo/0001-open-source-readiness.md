# 0001 — Open-source readiness: README, architecture document, licence hygiene

- **Area:** repository (root + `docs/`)
- **Status:** Implemented
- **Ticket:** [GGU-28](https://somniosoftware.atlassian.net/browse/GGU-28) · **Related:** [ADR-J](../../docs/adr/ADR-J-rest-api-and-a2a-surface.md), [ADR-K](../../docs/adr/ADR-K-response-shaping.md), [ADR-E](../../docs/adr/ADR-E-money-representation.md)
- **Owner:** Lautaro Bertuzzi · **Date:** 2026-09-19

## 1. Problem

The deliverable is a public reference application whose audience is Google's
reviewers and external Flutter developers, and **the repository had no
`README.md` at all**. It also had no `NOTICE` (the Apache 2.0 licence expects
one where third-party material is included, and the Flutter client is
substantially Google's `restaurant_finder` sample), no architecture document,
no contribution guide and no issue templates. Someone cloning it would find a
backend, an infrastructure directory and eleven ADRs with no entry point.

There is a second, sharper problem. The backend is real and the **Flutter
client has not been touched** — it still talks to the restaurant-finder agent.
A README that describes the intended system rather than the built one would be
the single most damaging document in the repository, because a reviewer would
discover the gap by failing to run it.

## 2. Scope

**In**

- `README.md` — what it is, the idea, **what is real and what is not**, how to
  run the backend, how to configure it, where to read next.
- `NOTICE` — Apache 2.0 notice and attribution to the upstream Google sample.
- `docs/ARCHITECTURE.md` — the as-built architecture, linking the diagrams and
  the ADRs, ending in a table of known gaps.
- `CONTRIBUTING.md` and `.github/ISSUE_TEMPLATE/`.
- `backend/scripts/mint_dev_token.py` + `make token` — without a token a fresh
  clone cannot call a single authenticated route, so "clone and run" would be
  false without it.
- A full-history secret scan as evidence.

**Out**

- Rewriting or renaming the Flutter client — **Epic 1**. Deliberately
  untouched; the documentation says so rather than hiding it.
- The catalog gallery and its component documentation — **GGU-22**.
- Source-file licence headers on new backend files. The upstream client files
  keep their Google headers as the licence requires; the backend is original
  work covered by `LICENSE` and `NOTICE`, and per-file headers on a codebase
  with a 150-line budget would cost more than they inform. Recorded as OD-2.

## 3. API contract

None. One additive developer command, `make token`, which signs with the HS256
development secret and therefore cannot mint anything a production service
would accept.

## 4. Data model & migration

None.

## 5. Security notes

- **The token script is local only.** It signs with `AUTH_JWT_SECRET`, the
  HS256 development secret. Production runs `AUTH_PROVIDER=oidc` and verifies
  RS256 signatures against an issuer's JWKS endpoint, so a token this script
  produces is worthless there. The script refuses to run when the secret is
  unset rather than inventing a default.
- **No secret may enter the repository or its history.** Proven by scanning
  every commit, not the diff.
- The README and the contribution guide both state that the model key and any
  service credentials are backend-only and never reach the client.

## 6. Acceptance criteria

1. **AC-1** — `LICENSE` is Apache 2.0 and a `NOTICE` attributes the upstream
   Google sample, whose files keep their original headers.
2. **AC-2** — Following the README alone, a developer with only Docker can run
   the backend, mint a token and call an authenticated route.
3. **AC-3** — `docs/ARCHITECTURE.md` describes the system **as built**, names
   what is not built, and matches the code.
4. **AC-4** — No secret exists in the repository or in its git history.
5. **AC-5** — The README states plainly what is real and what is simulated,
   including that the Flutter client is the upstream sample and that there is
   no market data, no broker and no execution.
6. **AC-6** — The architecture document, the diagrams, the ADRs, the specs, the
   security policy and the contribution guide are cross-linked.

## 7. Test plan

| AC | Evidence |
|---|---|
| AC-1 | `LICENSE` read (Apache 2.0, 227 lines); `NOTICE` names the upstream sample; 11 client files still carry `Copyright 2024 Google LLC` |
| AC-2 | The README's commands run for real: compose up on a clean database, `make token`, `GET /v1/me` → 200; the same call without the token → 401 |
| AC-3 | Written against the code, not the plan; every claim links to the diagram, ADR or module that backs it |
| AC-4 | `gitleaks` over the full history — 71 commits, no leaks |
| AC-5 | The "What is real and what is not" table, reviewed against the open pull requests |
| AC-6 | Links followed |

No unit tests: the change adds one script and documentation. `make gate` stays
green because the script is inside the budget and the quality suite.

## 8. Open decisions

| # | Question | Owner | Resolution |
|---|---|---|---|
| OD-1 | Does a documentation ticket need a spec at all? | TL — **yes** | The SDD rule is written for backend features, but "every decision is written down where the next person's Claude will find it" is not. This spec exists so the honesty decisions below are recorded rather than living in a pull request. It introduced `specs/repo/` for repository-level work. |
| OD-2 | Apache 2.0 per-file headers on backend sources? | TL — **no** | `LICENSE` plus `NOTICE` satisfies the licence; the upstream client files keep their Google headers as required. A 13-line header on files capped at 150 lines would consume the budget it is meant to protect. Revisit if a downstream consumer asks. |
| OD-3 | Should the README describe the intended system or the built one? | TL — **the built one, prominently** | A reviewer who discovers the Flutter gap by failing to run it trusts nothing else in the repository. The gap is stated in the second paragraph and again in a table. |
| OD-4 | `docs/architecture.md` or `docs/ARCHITECTURE.md`? | TL | Uppercase, matching `DEV_HARNESS.md` and the root convention. The ticket wrote it lowercase; on a case-insensitive filesystem it is the same file. |

## 9. Rollout & observability

None — documentation and one developer command. The architecture document
carries a "Known gaps" table that must shrink as GGU-3, Epic 1, GGU-29 and
GGU-22 land; leaving it stale is the main risk this spec creates.
