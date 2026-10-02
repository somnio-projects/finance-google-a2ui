# Architecture Decision Records

This registry was established on 2026-09-18 by the `/dev-epic-refinement` pass over
[GGU-6 "Epic 0 — Foundation"](https://somniosoftware.atlassian.net/browse/GGU-6). Before it, the
repository had no governing architectural records — every decision lived in Jira ticket prose,
which is consumed and closed rather than retained.

## Format

Each ADR carries a **WH(Y) statement** — *In the context of … facing … we decided … and neglected …
to achieve … accepting that …* — followed by numbered **D-N rulings**. Rulings are normative: code
review and the ship gate cite them by number.

## Status vocabulary

| Status | Meaning |
|---|---|
| **Accepted** | Ratified by the TL. Binding. |
| **Proposed** | Drafted, awaiting ratification. Tickets citing it carry a "pending ADR" Open Decision. |
| **Superseded by ADR-N** | Replaced. Kept for history; never deleted. |
| **Accepted · D-n superseded by D-m** | The record stands; one ruling inside it was replaced by a later ruling in the same record. The old `D-n` is struck through and kept — a citation by number must still resolve, and *why it was true once* is the part worth reading. Used when the context changed under a ruling rather than under the whole decision (ADR-F D-4, 2026-09-20). |

## Registry

| ADR | Title | Status | Gates |
|---|---|---|---|
| [ADR-A](ADR-A-session-identity.md) | Session identity, ownership and isolation | Accepted | GGU-46, GGU-5 |
| [ADR-B](ADR-B-auth-credential-contract.md) | Auth credential contract | Accepted · **D-4 superseded by D-11/D-12 (Proposed, 2026-09-20)** | GGU-2, GGU-46, GGU-87 |
| [ADR-C](ADR-C-backend-module-layout.md) | Backend module layout | Accepted | GGU-45 |
| [ADR-D](ADR-D-a2ui-streaming-transport.md) | A2UI streaming transport | Proposed | GGU-3, GGU-4 |
| [ADR-E](ADR-E-money-representation.md) | Money representation and rounding | Accepted | GGU-5 |
| [ADR-J](ADR-J-rest-api-and-a2a-surface.md) | Two surfaces: RESTful `/v1` + A2A protocol adapter | Accepted | GGU-3, GGU-46, Epic 1 |
| [ADR-K](ADR-K-response-shaping.md) | Response shaping: server-side projections, not client transformation | Accepted | GGU-49, GGU-16–21, GGU-36–39, GGU-41 |
| [ADR-F](ADR-F-persistence-and-session-lifetime.md) | In-memory persistence and session lifetime | Accepted · **D-4 superseded by D-7/D-8/D-9 (Proposed, 2026-09-20)** | GGU-5, GGU-3, GGU-29 |
| [ADR-G](ADR-G-secret-handling.md) | Secret handling in a public repository | Accepted | GGU-3, GGU-12 |
| [ADR-H](ADR-H-ci-ship-gate.md) | CI and ship-gate contract | Proposed · **D-2 and D-6 struck (2026-09-22)** — they named `client_flutter/`, retired by spec `repo/0002` | GGU-45 |
| [ADR-I](ADR-I-client-routing.md) | Client routing and auth gating (`client_flutter/` only) | **Superseded by ADR-L** (2026-09-22) — the app it governed was retired (spec `repo/0002`); D-3 survives, restated by ADR-L D-5 | GGU-1, GGU-2 |
| [ADR-L](ADR-L-client-architecture.md) | The `frontend/` client architecture | Proposed | GGU-91 |
| [ADR-M](ADR-M-a2ui-v1-wire.md) | A2UI v1.0 wire beside v0.9 — our own renderer, an additive `/a2ui/v1/*` route, the `frontend_v1/` copy | Accepted (2026-10-01) | — |

Letters are provisional identifiers from the refinement pass. Renumber to `ADR-0001…` on first
amendment if the team prefers sequential numbering; update the citations in the GGU-6 tickets at the
same time.
