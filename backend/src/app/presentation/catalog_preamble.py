"""The normative prose at the head of the generated contract (GGU-41).

It lives in its own module because it is the one part of the document a human
writes: what "frozen" means, who enforces it, and where the machine-readable
twin is. How to read a row is the other half, in ``catalog_legend``. Keeping
both beside the renderer rather than in a template file keeps the presentation
layer free of I/O (ADR-K D-6) and keeps every file inside the line budget.

The prose is written as wrapped bullet lists rather than Markdown tables: a
table row cannot be broken, and an unbreakable 200-character row inside a
Python string is a line-length violation with nowhere to go.
"""

from typing import Final

from app.presentation.catalog_legend import LEGEND

SPEC_LINK: Final[str] = (
    "[`specs/backend/0019-frozen-catalog-contract.md`]"
    "(../../specs/backend/0019-frozen-catalog-contract.md)"
)
SNAPSHOT_SPEC_LINK: Final[str] = (
    "[`specs/backend/0021-machine-readable-catalog.md`]"
    "(../../specs/backend/0021-machine-readable-catalog.md)"
)

PREAMBLE: Final[str] = f"""# Frozen catalog contract

<!-- GENERATED FILE — do not edit by hand.
     Regenerate with: cd backend && make catalog -->

**Source of truth:** the projection registry in `backend/src/app/presentation/`,
under [ADR-K](../adr/ADR-K-response-shaping.md) D-14.
**Ticket:** [GGU-41](https://somniosoftware.atlassian.net/browse/GGU-41) ·
**Spec:** {SPEC_LINK}

This is the designer-facing field inventory GGU-41 asks for: for every catalog
component, the fields it receives, their format, whether they are required,
whether they arrive pre-formatted, which UI state they drive and which of them
are editable. It is **generated from the registry**, not transcribed from it.
A transcription is a second source of truth, and the second source is the one
that goes stale — which is the exact failure this contract exists to prevent.

Nothing needs copying out of here by hand either: the page the UI Kit binds to
is this file, cited by its projection ids and digests.

**For a machine, read the twin.** Markdown is for people, and a client test
cannot parse a table, so the same promise is rendered as JSON in
[`view-catalog.snapshot.json`](view-catalog.snapshot.json) — per view the
component type, the view id, the digest, the field paths, the options schema
and the rendered example (GGU-53, spec {SNAPSHOT_SPEC_LINK}). Both files come
out of one render pass over the registry and are gated by the same command, so
they cannot disagree with each other or with the code.

## What "frozen" means

Frozen does **not** mean a human promised not to change a field. It means
**drift is detected**:

- **A versioned id is immutable.** Once a client binds to
  `<component>.<variant>.v1`, that shape is fixed. A change arrives as a new id
  (`…v2`), never as a mutation of `v1` (ADR-K D-9).
- **A digest proves it.** Each component below carries a 12-character digest
  over everything it promises — id, summary, serving endpoints, options schema,
  payload schema and rendered example. That digest is the frozen version
  identifier the prompt fragments (GGU-14) and the Figma UI Kit cite. If a `v1`
  digest changes, something that was frozen moved.
- **The ship gate enforces it.** `make gate` re-renders this document from the
  registry and diffs it against the checked-in file. Any difference fails the
  gate and prints the command that fixes it:

  ```
  cd backend && make catalog
  ```

  So a projection cannot change without this file changing in the same commit,
  and a reviewer sees the moved field as a diff in the contract rather than
  discovering it after the design work is done.

{LEGEND}
"""

__all__ = ["PREAMBLE", "SNAPSHOT_SPEC_LINK", "SPEC_LINK"]
