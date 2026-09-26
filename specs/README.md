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
├── client/            NNNN-<topic>.md   — CLOSED. See below
└── frontend/          NNNN-<feature>.md — the A2UI client (frontend/)
```

One area per solution folder, so `frontend/`'s specs are found where its code
is.

**`client/` is a closed area: no new spec goes there.** It held the specs for
`client_flutter/`, the older of two Flutter apps, which was retired on
2026-09-22 by [`repo/0002`](repo/0002-retire-the-client-flutter-app.md).
`0001` and `0002` are `Superseded` and kept in place; `0003-client-backend-contract.md`
is **still live** — its subject is the backend's contract rather than that
app, and `frontend/` binds it. A new client spec goes in `frontend/`.

Numbers are per area, zero-padded, never reused. The filename is stable once
merged; a replaced spec is marked `Superseded by NNNN` and kept.

**Three of those properties are now checked** — `repo.spec-numbers`
(`scripts/check_spec_numbers.sh`, spec [`frontend/0029`](frontend/0029-the-conventions-are-checked.md)):
the filename is `NNNN-lowercase-kebab-slug.md`, no two specs in an area share a
number, and every spec has exactly one row in the index below. Until GGU-105
none of it was, and two specs had shared `frontend/0002` since the day they
merged while nine files had no row at all. *Never reused* is the one property
left to people: in git history a renumbering is a delete plus an add, which is
exactly what a reuse looks like, so the check would have failed on a legitimate
rename. What keeps it true is the rule above — a superseded spec keeps its file
and its row, so a number in use stays visible.

A **gap** is not a defect and is not flagged: `frontend/0027` and `0028` are
free and the renumbering that resolved the `0002` collision chose `0030`
deliberately, above the numbers two branches in flight were about to take.
"Next free" is evaluated at a branch point, which is why picking the lowest one
is how collisions happen.

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

One row per file, and **exactly** one — `repo.spec-numbers` fails the build on a
spec with no row, a spec with two, and a row over a file that does not exist.

The table used to claim it was "ordered by area then number — so a missing spec
and a duplicated one are both visible at a glance." It was neither ordered nor
complete, and neither the duplicate nor the nine unlisted files had been visible
to anyone. Ordering is a reading convenience and is deliberately **not**
asserted: reordering seventy rows is not what makes a collision fail, and a
claim this file cannot keep is what GGU-105 was cut for. Rows are appended.

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
| [backend/0025-the-design-portfolio.md](backend/0025-the-design-portfolio.md) | Implemented — **OD-2 superseded by backend/0044** | *unassigned* (PR #81) |
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
| [backend/0034-the-catalog-serves-the-gallery.md](backend/0034-the-catalog-serves-the-gallery.md) | In progress | *unassigned* (GGU-101..104 named as gaps) |
| [backend/0037-the-agent-reaches-the-catalog-or-says-why-not.md](backend/0037-the-agent-reaches-the-catalog-or-says-why-not.md) | In progress | *unassigned* |
| [backend/0036-the-turn-is-fast-honest-and-observable.md](backend/0036-the-turn-is-fast-honest-and-observable.md) | In progress | *unassigned* |
| [frontend/0016-component-catalog-gallery.md](frontend/0016-component-catalog-gallery.md) | In progress | *unassigned* (GGU-101..104 named as gaps) |
| [frontend/0017-the-client-runs-in-the-stack-and-ships-itself.md](frontend/0017-the-client-runs-in-the-stack-and-ships-itself.md) | In progress | *unassigned* |
| [frontend/0019-the-turn-always-ends.md](frontend/0019-the-turn-always-ends.md) | In progress | *unassigned* |
| [frontend/0021-three-defects-a-reader-found.md](frontend/0021-three-defects-a-reader-found.md) | In progress | *unassigned* |
| [frontend/0015-loading-states.md](frontend/0015-loading-states.md) | In progress | *unassigned* |
| [backend/0038-the-openapi-document-is-complete.md](backend/0038-the-openapi-document-is-complete.md) | Implemented | *unassigned* |
| [backend/0039-the-surface-answers-the-question-that-was-asked.md](backend/0039-the-surface-answers-the-question-that-was-asked.md) | In progress | *unassigned* |
| [backend/0040-sso-enrols-itself.md](backend/0040-sso-enrols-itself.md) | In progress | *unassigned* |
| [backend/0041-a-job-provisions-the-demo-audience.md](backend/0041-a-job-provisions-the-demo-audience.md) | In progress | *unassigned* |
| [backend/0042-asking-for-access-is-not-a-worse-state.md](backend/0042-asking-for-access-is-not-a-worse-state.md) | In progress | *unassigned* |
| [frontend/0020-transition-states.md](frontend/0020-transition-states.md) | In progress | *unassigned* |
| [frontend/0022-the-deployed-client-has-a-policy-no-test-sees.md](frontend/0022-the-deployed-client-has-a-policy-no-test-sees.md) | In progress | *unassigned* |
| [backend/0035-the-portfolio-has-an-owner-and-the-tabs-really-filter.md](backend/0035-the-portfolio-has-an-owner-and-the-tabs-really-filter.md) | Draft | *unassigned* |
| [frontend/0018-the-tabs-search-and-filter-for-real.md](frontend/0018-the-tabs-search-and-filter-for-real.md) | Draft | *unassigned* |
| [frontend/0023-voice-input.md](frontend/0023-voice-input.md) | In progress | *unassigned* |
| [frontend/0024-the-header-stays-put.md](frontend/0024-the-header-stays-put.md) | In progress | *unassigned* (TL request 2026-09-22) |
| [frontend/0025-failures-have-a-way-out.md](frontend/0025-failures-have-a-way-out.md) | In progress | GGU-110 · GGU-111 · GGU-112 |
| [frontend/0026-the-ticket-in-the-assistant-is-editable.md](frontend/0026-the-ticket-in-the-assistant-is-editable.md) | In progress | GGU-113 |
| [backend/0044-the-portfolio-is-crypto.md](backend/0044-the-portfolio-is-crypto.md) | In progress | GGU-114 |
| [backend/0045-every-account-gets-todays-seed.md](backend/0045-every-account-gets-todays-seed.md) | In progress | GGU-126 |
| [frontend/0028-the-waterfall-matches-the-ui-kit.md](frontend/0028-the-waterfall-matches-the-ui-kit.md) | In progress | GGU-115 |
| [frontend/0027-the-taxlot-table-matches-the-ui-kit.md](frontend/0027-the-taxlot-table-matches-the-ui-kit.md) | In progress | GGU-116 |
| [backend/0046-no-equity-vocabulary-in-a-crypto-payload.md](backend/0046-no-equity-vocabulary-in-a-crypto-payload.md) | In progress | GGU-122 · GGU-123 · GGU-119 |
| [backend/0047-the-db-backed-suite-cleans-up-after-itself.md](backend/0047-the-db-backed-suite-cleans-up-after-itself.md) | In progress | GGU-124 |
| [backend/0048-the-metadata-knows-every-table.md](backend/0048-the-metadata-knows-every-table.md) | In progress | GGU-127 |
| [backend/0049-the-taxlot-table-gains-its-missing-fields.md](backend/0049-the-taxlot-table-gains-its-missing-fields.md) | In progress | GGU-117 |
| [backend/0050-the-ticket-gains-a-slider-and-one-honest-button.md](backend/0050-the-ticket-gains-a-slider-and-one-honest-button.md) | In progress | GGU-137 |
| [backend/0051-the-comparison-ranks-what-it-can-defend.md](backend/0051-the-comparison-ranks-what-it-can-defend.md) | In progress | GGU-136 |
| [client/0001-client-foundation.md](client/0001-client-foundation.md) | **Superseded by repo/0002** | GGU-82 |
| [client/0002-client-delivery.md](client/0002-client-delivery.md) | **Superseded by repo/0002** | GGU-82 |
| [client/0003-client-backend-contract.md](client/0003-client-backend-contract.md) | Draft — **live**, bound by `frontend/` | GGU-82 |
| [frontend/0001-frontend-skeleton.md](frontend/0001-frontend-skeleton.md) | Implemented | GGU-91 |
| [infra/0001-dev-environment.md](infra/0001-dev-environment.md) | Draft | GGU-29 |
| [infra/0002-firebase-sign-in-on-dev.md](infra/0002-firebase-sign-in-on-dev.md) | In progress | *unassigned* |
| [infra/0003-the-migrate-job-runs-the-released-image.md](infra/0003-the-migrate-job-runs-the-released-image.md) | In progress | *unassigned* |
| [infra/0004-cd-owns-every-job-image.md](infra/0004-cd-owns-every-job-image.md) | In progress | *unassigned* |
| [infra/0005-the-deployer-can-reach-the-jobs-it-owns.md](infra/0005-the-deployer-can-reach-the-jobs-it-owns.md) | In progress | *unassigned* |
| [repo/0001-open-source-readiness.md](repo/0001-open-source-readiness.md) | Implemented | GGU-28 |
| [repo/0002-retire-the-client-flutter-app.md](repo/0002-retire-the-client-flutter-app.md) | In progress | *unassigned* (TL request 2026-09-22) |
| [repo/0003-the-interpreter-pin-has-one-home.md](repo/0003-the-interpreter-pin-has-one-home.md) | Implemented | GGU-125 |
| [backend/0021-machine-readable-catalog.md](backend/0021-machine-readable-catalog.md) | Implemented | GGU-53 (server half) |
| [backend/0043-the-screen-can-ask-which-door-this-is.md](backend/0043-the-screen-can-ask-which-door-this-is.md) | In progress | *unassigned* |
| [frontend/0002-chart-primitives-and-waterfall.md](frontend/0002-chart-primitives-and-waterfall.md) | Draft | GGU-55 (design GGU-42) |
| [frontend/0003-taxlot-table.md](frontend/0003-taxlot-table.md) | Implemented | GGU-57 (serving GGU-17) |
| [frontend/0004-scenario-comparison.md](frontend/0004-scenario-comparison.md) | Draft | GGU-59 (serving GGU-18) |
| [frontend/0005-payoff-chart.md](frontend/0005-payoff-chart.md) | Implemented | GGU-63 (parent GGU-20) |
| [frontend/0006-order-ticket.md](frontend/0006-order-ticket.md) | Implemented | GGU-61 (the Flutter half of GGU-19) |
| [frontend/0007-allocation-summary.md](frontend/0007-allocation-summary.md) | Draft | GGU-65 (the Flutter half of GGU-21) |
| [frontend/0029-the-conventions-are-checked.md](frontend/0029-the-conventions-are-checked.md) | In progress | GGU-105 · GGU-106 |
| [frontend/0030-a2ui-agent-path.md](frontend/0030-a2ui-agent-path.md) | Implemented | GGU-79 — **renumbered from `0002`** by `frontend/0029` |
| [frontend/0031-the-comparison-is-measured.md](frontend/0031-the-comparison-is-measured.md) | In progress | GGU-141 |
