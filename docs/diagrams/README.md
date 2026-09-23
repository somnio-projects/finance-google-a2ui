# Architecture diagrams

Every structural fact about this system has a picture here, and every picture is
**text** — Mermaid inside Markdown, so it diffs in a PR, renders on GitHub with
no tooling, and can never drift silently from the code that a screenshot would.

## Index

| Diagram | Answers | Kept true by |
|---|---|---|
| [01-system-context.md](01-system-context.md) | Who uses the system and what it talks to | ADR-J, `docs/compliance/CLOUD_SERVICES.md` |
| [02-containers.md](02-containers.md) | The deployable pieces and the protocols between them | ADR-F, ADR-J |
| [03-backend-layers.md](03-backend-layers.md) | The layering and which direction dependencies point | `.claude/rules/backend/architecture.md` |
| [04-request-lifecycle.md](04-request-lifecycle.md) | What happens to one authenticated request | `backend/docs/SECURITY.md`, `bootstrap.py` |
| [05-agent-turn.md](05-agent-turn.md) | How a question becomes streamed UI surfaces | ADR-D, ADR-K, GGU-47 |
| [06-response-shaping.md](06-response-shaping.md) | How a payload is shaped and who chooses the shape | ADR-K |
| [07-data-model.md](07-data-model.md) | The persisted tables and their relations | `backend/alembic/versions/` |
| [08-infrastructure.md](08-infrastructure.md) | The production topology on Google Cloud | `infra/`, ADR-F |
| [09-delivery-pipeline.md](09-delivery-pipeline.md) | Where each check runs and what reaches production | `.claude/rules/ci-conventions.md` |
| [10-branching.md](10-branching.md) | How work flows from a ticket to production | `docs/compliance/CHANGE_MANAGEMENT.md` |
| [12-frontend-layers.md](12-frontend-layers.md) | What may import what in the `frontend/` client | ADR-L, `frontend/app/test/architecture/layering_test.dart` |
| [13-client-delivery.md](13-client-delivery.md) | How the A2UI client reaches a browser | `specs/frontend/0017`, `.github/workflows/frontend-cd.yaml`, `infra/scripts/tests/test_dev_environment.sh` |

**11 is missing on purpose.** `11-client-architecture.md` drew `client_flutter/`,
the older of two Flutter apps. That app was retired on 2026-09-22 (spec
[`repo/0002`](../../specs/repo/0002-retire-the-client-flutter-app.md)) and the
diagram was **deleted rather than superseded**: rule 1 below says a diagram
draws what is there, and a picture of a directory that does not exist has no
honest form. The question it answered — what may import what in the Flutter
client — is [12](12-frontend-layers.md)'s for the app that remains. Numbers are
reading order and are **never reused**, so the next diagram is 14.

## Rules

1. **A structural change updates its diagram in the same PR.** New layer, new table, new service, new dependency, new environment, changed flow — the picture moves with the code. A PR that changes structure and leaves a diagram stale is incomplete.
2. **Mermaid in Markdown only.** No binary exports, no external editors, no image files. If a diagram needs a legend, write it under the fence.
3. **One question per diagram.** A picture that answers three questions answers none well. Split it and link.
4. **Say what is real and what is planned.** Anything not deployed yet is drawn with a dashed edge or a `(planned)` label, exactly as the compliance corpus does — a diagram must never imply capability we do not have.
5. **Link, do not repeat.** The diagram shows the shape; the ADR, spec or rule carries the reasoning. Each diagram names its source of truth in a line under the title.

## Conventions

- Direction top-down for structure, left-right for flows.
- `subgraph` per trust boundary (browser · our service · Google Cloud · third parties).
- Node ids are stable (`api`, `svc`, `repo`, `db`) so diffs stay readable.
- Comments (`%%`) record why an edge exists when it is not obvious.
