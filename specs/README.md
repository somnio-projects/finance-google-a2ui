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
├── infra/             NNNN-<topic>.md   — Google Cloud infrastructure (infra/) and the delivery pipeline
├── repo/              NNNN-<topic>.md   — repository-level work: licensing, docs, hygiene
├── client/            NNNN-<feature>.md — the client_flutter/ app and the backend contract both apps bind
└── frontend/          NNNN-<feature>.md — the A2UI client (frontend/)
```

One area per solution folder, so `frontend/`'s specs are found where its code
is. `client/` keeps the specs that are not one app's — chiefly
`0003-client-backend-contract.md`, which both Flutter apps bind.

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

One row per file, ordered by area then number — so a missing spec and a
duplicated one are both visible at a glance.

| Spec | Status | Ticket |
|---|---|---|
| [backend/0001-backend-foundation.md](backend/0001-backend-foundation.md) | Implemented | GGU-3 / GGU-45 / GGU-46 (re-baselined) |
| [backend/0002-feature-flags.md](backend/0002-feature-flags.md) | Implemented | — (TL request 2026-09-18) |
| [backend/0003-portfolio-domain.md](backend/0003-portfolio-domain.md) | Implemented | GGU-5 |
| [backend/0004-session-identity.md](backend/0004-session-identity.md) | Draft | GGU-46 |
| [backend/0005-presentation-layer.md](backend/0005-presentation-layer.md) | Implemented | GGU-49 |
| [backend/0006-agent-host.md](backend/0006-agent-host.md) | Implemented | GGU-47 |
| [backend/0007-cd-pipeline.md](backend/0007-cd-pipeline.md) | Approved | GGU-48 |
| [backend/0008-attribution-tool.md](backend/0008-attribution-tool.md) | Implemented | GGU-36 |
| [backend/0009-prompt-fragments.md](backend/0009-prompt-fragments.md) | Implemented | GGU-14 |
| [backend/0010-a2a-surface.md](backend/0010-a2a-surface.md) | Implemented | GGU-3 |
| [backend/0011-holdings-tool.md](backend/0011-holdings-tool.md) | Implemented | GGU-39 |
| [backend/0012-delivery-followups.md](backend/0012-delivery-followups.md) | Implemented | — (ADR-K D-18/D-19/D-20 follow-ups) |
| [backend/0013-simulate-sale-tool.md](backend/0013-simulate-sale-tool.md) | Implemented | GGU-37 |
| [backend/0014-payoff-tool.md](backend/0014-payoff-tool.md) | Implemented | GGU-38 (re-baselined) |
| [backend/0015-tax-lot-table-projection.md](backend/0015-tax-lot-table-projection.md) | Implemented | GGU-41 |
| [backend/0016-payoff-curve-projection.md](backend/0016-payoff-curve-projection.md) | Implemented | GGU-41 |
| [backend/0017-scenario-comparison-projection.md](backend/0017-scenario-comparison-projection.md) | Implemented | GGU-41 |
| [backend/0018-order-ticket-projection.md](backend/0018-order-ticket-projection.md) | Draft | GGU-41 |
| [backend/0019-frozen-catalog-contract.md](backend/0019-frozen-catalog-contract.md) | Implemented | GGU-41 (re-baselined) |
| [backend/0020-portfolio-persistence.md](backend/0020-portfolio-persistence.md) | Approved | GGU-29 follow-up |
| [backend/0022-surface-actions.md](backend/0022-surface-actions.md) | Implemented | GGU-78 |
| [backend/0023-catalog-serves-the-client.md](backend/0023-catalog-serves-the-client.md) | Implemented | GGU-53 |
| [backend/0024-contract-serves-the-designs.md](backend/0024-contract-serves-the-designs.md) | Implemented | GGU-99 (closes GGU-101/103/104 in part) |
| [backend/0025-the-design-portfolio.md](backend/0025-the-design-portfolio.md) | Implemented | *unassigned* (PR #81) |
| [backend/0026-the-home-shell.md](backend/0026-the-home-shell.md) | Implemented | *unassigned* (PR #81) |
| [backend/0027-user-provisioning.md](backend/0027-user-provisioning.md) | In progress | *unassigned* |
| [backend/0028-holdings-and-activity.md](backend/0028-holdings-and-activity.md) | In progress | *unassigned* |
| [frontend/0009-holdings-and-activity-tabs.md](frontend/0009-holdings-and-activity-tabs.md) | In progress | *unassigned* |
| [backend/0029-the-turn-recommends-its-chips.md](backend/0029-the-turn-recommends-its-chips.md) | In progress | *unassigned* |
| [frontend/0011-the-assistant-as-designed.md](frontend/0011-the-assistant-as-designed.md) | In progress | *unassigned* |
| [backend/0030-the-greeting-names-the-caller.md](backend/0030-the-greeting-names-the-caller.md) | In progress | *unassigned* |
| [backend/0031-order-ticket-v2.md](backend/0031-order-ticket-v2.md) | In progress | GGU-108 |
| [frontend/0012-details-the-review-found.md](frontend/0012-details-the-review-found.md) | In progress | *unassigned* |
| [backend/0033-the-simulated-assistant-offline.md](backend/0033-the-simulated-assistant-offline.md) | In progress | *unassigned* |
| [frontend/0013-order-ticket-v2.md](frontend/0013-order-ticket-v2.md) | In progress | GGU-108 |
| [frontend/0008-sign-in.md](frontend/0008-sign-in.md) | In progress | *unassigned* |
| [frontend/0010-appearance-selector.md](frontend/0010-appearance-selector.md) | In progress | *unassigned* |
| [backend/0032-attribution-headline-and-driver-detail.md](backend/0032-attribution-headline-and-driver-detail.md) | In progress | GGU-100 (the waterfall fields); the drill-down card *unassigned* |
| [frontend/0014-flow-a-drill-down.md](frontend/0014-flow-a-drill-down.md) | In progress | GGU-100 (the binding); the card *unassigned* |
| [backend/0031-the-catalog-serves-the-gallery.md](backend/0031-the-catalog-serves-the-gallery.md) | In progress | *unassigned* (GGU-101..104 named as gaps) |
| [frontend/0013-component-catalog-gallery.md](frontend/0013-component-catalog-gallery.md) | In progress | *unassigned* (GGU-101..104 named as gaps) |
| [client/0001-client-foundation.md](client/0001-client-foundation.md) | Draft | GGU-82 |
| [client/0002-client-delivery.md](client/0002-client-delivery.md) | Draft | GGU-82 |
| [client/0003-client-backend-contract.md](client/0003-client-backend-contract.md) | Draft | GGU-82 |
| [frontend/0001-frontend-skeleton.md](frontend/0001-frontend-skeleton.md) | Implemented | GGU-91 |
| [infra/0001-dev-environment.md](infra/0001-dev-environment.md) | Draft | GGU-29 |
| [repo/0001-open-source-readiness.md](repo/0001-open-source-readiness.md) | Implemented | GGU-28 |
