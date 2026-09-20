#!/usr/bin/env python3
"""Write or verify the generated catalog artefacts (GGU-41, GGU-53).

Two files, one render pass over the projection registry: the designer-facing
`docs/catalog/CONTRACT.md` and the machine-readable
`docs/catalog/view-catalog.snapshot.json` the Flutter catalog test loads.
Neither can describe a component the backend does not serve, and neither can
miss one it does.

This file is the only part of the generator that touches the disk; everything
it writes is built by ``app.presentation.catalog_artifacts``, which is pure and
covered.

Usage:
    python scripts/generate_catalog_contract.py            # write the files
    python scripts/generate_catalog_contract.py --check    # fail when stale
"""

import sys
from pathlib import Path

from app.presentation.catalog_artifacts import Rendered, render_all
from app.presentation.catalog_json import FIX_COMMAND
from app.presentation.registry import REGISTRY
from app.presentation.views import LOADED

REPO_ROOT = Path(__file__).resolve().parents[2]


def write(rendered: Rendered) -> None:
    """Write one artefact to disk, creating its directory if needed."""
    target = REPO_ROOT / rendered.path
    target.parent.mkdir(parents=True, exist_ok=True)
    _ = target.write_text(rendered.generated, encoding="utf-8")
    print(f"wrote {rendered.path} from {len(LOADED)} view module(s)")


def check(rendered: Rendered) -> bool:
    """Return True when the checked-in artefact matches the registry."""
    target = REPO_ROOT / rendered.path
    checked_in = target.read_text(encoding="utf-8") if target.exists() else ""
    drift = rendered.drift(checked_in)
    if not drift:
        print(f"{rendered.path} is current ({len(REGISTRY.all())} projections)")
        return True
    print(drift, end="")
    print(f"\n{rendered.path} is stale — a projection changed. Regenerate it:")
    print(f"  {FIX_COMMAND}")
    return False


def main(argv: list[str]) -> int:
    """Return 0 when every artefact is written or already current, 1 otherwise."""
    artifacts = render_all(REGISTRY.all())
    if "--check" not in argv:
        for rendered in artifacts:
            write(rendered)
        return 0
    # A list, not a generator: every artefact is reported, so one stale file
    # does not hide the other behind a short circuit.
    outcomes = [check(rendered) for rendered in artifacts]
    return 0 if all(outcomes) else 1


if __name__ == "__main__":  # pragma: no cover - CLI guard
    sys.exit(main(sys.argv[1:]))
