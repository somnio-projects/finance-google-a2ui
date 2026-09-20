# Specs — Spec-Driven Development

Every feature in this repository starts as a spec here, before any code. The
spec is the contract the implementation, the tests and the PR are checked
against; the reviewer agent reads it, and the acceptance criteria numbers show
up in test names and PR descriptions.

## Layout

```
specs/
├── README.md          this file
├── TEMPLATE.md        copy me
├── backend/           NNNN-<feature>.md — FastAPI service (backend/)
├── repo/              NNNN-<topic>.md   — repository-level work: licensing, docs, hygiene
└── client/            NNNN-<feature>.md — Flutter client (client_flutter/), when it adopts SDD
```

Numbers are per area, zero-padded, never reused. The filename is stable once
merged; a replaced spec is marked `Superseded by NNNN` and kept.

## Status lifecycle

| Status | Meaning |
|---|---|
| Draft | Being written; not yet reviewed |
| Approved | Reviewed by the TL; implementation may start |
| Implemented | Code merged; ACs verified by the gate and the PR |
| Superseded | Replaced by a newer spec (linked) |

## How to write one

Run `/spec <area> <feature> [GGU-n]` or copy `TEMPLATE.md`. Keep it short and
precise: a spec that a developer's Claude can implement without asking is the
target. Link the Jira ticket, the ADRs it depends on (`docs/adr/` on the
`docs/ggu-6-foundation-adrs` branch until PR #1 merges) and any related spec.

## Index

| Spec | Status | Ticket |
|---|---|---|
| [backend/0001-backend-foundation.md](backend/0001-backend-foundation.md) | Implemented | GGU-3 / GGU-45 / GGU-46 (re-baselined) |
| [backend/0002-feature-flags.md](backend/0002-feature-flags.md) | Implemented | — (TL request 2026-09-18) |
| [backend/0003-portfolio-domain.md](backend/0003-portfolio-domain.md) | Implemented | GGU-5 |
| [backend/0005-presentation-layer.md](backend/0005-presentation-layer.md) | Implemented | GGU-49 |
| [backend/0006-agent-host.md](backend/0006-agent-host.md) | Implemented | GGU-47 |
| [backend/0008-attribution-tool.md](backend/0008-attribution-tool.md) | Implemented | GGU-36 |
| [backend/0009-prompt-fragments.md](backend/0009-prompt-fragments.md) | Implemented | GGU-14 |
| [backend/0010-a2a-surface.md](backend/0010-a2a-surface.md) | Implemented | GGU-3 |
| [backend/0012-delivery-followups.md](backend/0012-delivery-followups.md) | Implemented | — (ADR-K D-18/D-19/D-20 follow-ups) |
| [backend/0011-holdings-tool.md](backend/0011-holdings-tool.md) | Implemented | GGU-39 |
| [backend/0013-simulate-sale-tool.md](backend/0013-simulate-sale-tool.md) | Implemented | GGU-37 |
| [backend/0014-payoff-tool.md](backend/0014-payoff-tool.md) | Implemented | GGU-38 (re-baselined) |
| [backend/0019-frozen-catalog-contract.md](backend/0019-frozen-catalog-contract.md) | Implemented | GGU-41 (re-baselined) |
| [backend/0015-tax-lot-table-projection.md](backend/0015-tax-lot-table-projection.md) | Implemented | GGU-41 |
| [backend/0016-payoff-curve-projection.md](backend/0016-payoff-curve-projection.md) | Implemented | GGU-41 |
| [backend/0017-scenario-comparison-projection.md](backend/0017-scenario-comparison-projection.md) | Implemented | GGU-41 |
| [backend/0013-simulate-sale-tool.md](backend/0013-simulate-sale-tool.md) | Implemented | GGU-37 |
| [repo/0001-open-source-readiness.md](repo/0001-open-source-readiness.md) | Implemented | GGU-28 |
| [backend/0003-portfolio-domain.md](backend/0003-portfolio-domain.md) | Implemented | GGU-5 |
| [backend/0006-agent-host.md](backend/0006-agent-host.md) | Implemented | GGU-47 |
