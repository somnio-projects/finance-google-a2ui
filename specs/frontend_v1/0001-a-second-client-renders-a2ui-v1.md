# 0001 — A second client renders A2UI v1.0

**Status:** Draft — awaiting TL approval · **Ticket:** *unassigned* · **Area:** `frontend_v1/`
**Decision:** [ADR-M](../../docs/adr/ADR-M-a2ui-v1-wire.md) · **Pair:** [`backend/0053`](../backend/0053-the-agent-speaks-a2ui-v1.md)

## 1. Problem

The v1.0 showcase needs a Flutter client that renders real A2UI v1.0 messages.
No public Flutter renderer supports v1.0 (a2ui-project/a2ui#2899), and
`frontend/` (v0.9, `finance-a2ui.web.app`) must not change.

## 2. Scope

**In:** Patricio's plan M-16…M-20 as a **new app** in `frontend_v1/`:

- `packages/a2ui_v1` — pure Dart, no Flutter, no A2UI dependency: message
  models for every agent→renderer and renderer→agent message the examples
  use, a `SurfaceProcessor` (create/update/delete, adjacency list, buffered
  until `root`, JSON-Pointer data model with `updateDataModel` replace/delete),
  catalog composition validation (`UNALLOWED_PARENT` / `UNALLOWED_CHILD`)
  read from the generated catalog, and the `callAgentFunction` / `action`
  builders.
- `app/` — the copied app; its assistant screen now asks over v1.0: render each surface as it streams, edits through `renderView`, drill as
  `action`, chips as text, the designed error state. A `SurfaceHost` walks the
  tree, wraps every node in `Semantics` from `accessibility`, and maps
  component name → widget through a generated manifest.
- The ten finance widgets, **copied** from `frontend/app/lib/components` and
  `frontend/app/lib/charts` (an app cannot be a dependency), bound to
  `dataModel[<id>].payload` — the same payload, so zero transformation and the
  same goldens. `Section` is new.
- `frontend/packages/finance_core`, `finance_charts`, `finance_auth` are used
  through **path** dependencies, read-only.
- Own pub workspace, `.fvmrc` (3.47.5), `Makefile` with `make gate`
  (toolchain · format · analyze · budget · manifest · tests · 100 % line
  coverage), `Dockerfile`, `firebase.json` for its own Hosting site.

**It is the same app, upgraded.** `frontend_v1/` starts as a copy of the
whole `frontend/` workspace at the `develop` sha recorded in its README —
every screen, route, theme, auth flow and REST screen identical, connected to
the same backend, database and Firebase project and web app. The **only**
behavioural change is the assistant's wire: v0.9 `render-intent` + REST fetch
becomes A2UI v1.0 through `a2ui_v1` and `POST /a2ui/v1/a2a`. The list above
describes that change; everything else is the copy.

**Out:** any edit to `frontend/`. Mobile builds. Moving to `a2ui_flutter`
(later, behind `a2ui_v1`'s API).

## 3. API contract

Binds `backend/0053` §3 and the files in `docs/a2ui/v1.0/examples/` verbatim.
Sends `X-A2A-Extensions: https://a2ui.org/a2a-extension/a2ui/v1.0` and
`a2uiRendererCapabilities` on every message.

## 5. Security notes

Bearer token from Firebase as `frontend/` does. CSP `connect-src` only the
backend origin. No logging of payloads.

## 6. Acceptance criteria

- **AC-1** `a2ui_v1` parses every file in `docs/a2ui/v1.0/examples/` and
  round-trips the renderer→agent ones byte-equivalent (JSON-equal).
- **AC-2** The processor builds the tree for both `surface.*` examples,
  buffers components until `root`, applies `updateDataModel` at a path, and
  deletes on `null`.
- **AC-3** A tree violating the catalog's composition rules renders the
  allowed part and reports the code.
- **AC-4** Each of the ten components renders from its v1.0 example with no
  transformation; the numbers rule holds (`NumberFormat`, `dart:math`,
  `DateTime.now()` absent from `lib/`).
- **AC-5** An edit sends `callAgentFunction(renderView)` and the widget
  updates from the following `updateDataModel`; an error response shows the
  designed error state.
- **AC-6** Tapping a waterfall bar sends `action(drill_attribution)`.
- **AC-7** Every node carries `Semantics` from `accessibility`.
- **AC-8** Nothing under `frontend/` changes.

## 7. Test plan

Pure-Dart tests for `a2ui_v1` against the examples; widget tests with the
pump harness; goldens copied with their widgets. 100 % line coverage per file.

## 8. Open decisions

ADR-M OD-1 (Hosting site id), OD-3 (SSO allow-list).
