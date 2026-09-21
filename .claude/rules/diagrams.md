# Architecture diagrams rule

Every structural fact about this system is drawn in [`docs/diagrams/`](../../docs/diagrams/README.md),
as **Mermaid inside Markdown** — text that diffs in a PR and renders on GitHub
with no tooling. Screenshots and binary exports are not accepted: they drift
silently and cannot be reviewed.

## When a diagram must change

In the **same PR** as the code, whenever the change adds or alters:

| Change | Diagram |
|---|---|
| A new external dependency, client or integration | `01-system-context.md` |
| A new deployable, protocol or trust boundary | `02-containers.md` |
| A new layer, package or dependency direction | `03-backend-layers.md` |
| Middleware, auth, or the error/audit path | `04-request-lifecycle.md` |
| Anything in the agent turn, tools or streaming | `05-agent-turn.md` |
| A projection, option or selection rule | `06-response-shaping.md` |
| A table, column or relation (i.e. any migration) | `07-data-model.md` |
| Terraform: network, runtime, secrets, observability | `08-infrastructure.md` |
| A check moving between pre-commit, CI or CD | `09-delivery-pipeline.md` |
| The branch model or the ticket lifecycle | `10-branching.md` |
| A client layer, a feature slice or what a layer may import | `11-client-architecture.md` |

A PR that changes structure and leaves its diagram stale is **incomplete** —
the `backend-reviewer` agent flags it and review blocks on it.

## How to write one

- **One question per diagram.** Name it in the first line, under the title, together with its source of truth (the ADR, spec or rule that carries the reasoning). The diagram shows shape; it never re-argues a decision.
- **Draw reality, label intent.** Anything not deployed is a dashed edge or a `(planned)` label. A diagram must never imply a capability that does not exist — the same honesty rule the compliance corpus follows.
- **Stable node ids** (`api`, `svc`, `repo`, `db`) so a diff shows the change, not a renumbering.
- **`subgraph` per trust boundary**: client · our service · Google Cloud · third parties.
- **`%%` comments** for the non-obvious: why an edge exists, what is forbidden, what the reader would otherwise get wrong.
- Keep it readable on a phone: if it needs more than ~15 nodes, it is two diagrams.

## New diagrams

Add the file as `NN-<slug>.md`, register it in `docs/diagrams/README.md` with
the question it answers and what keeps it true, and link it from the ADR or
spec it illustrates. Diagrams are numbered in reading order, not creation order.
