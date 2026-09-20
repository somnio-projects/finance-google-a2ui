#!/usr/bin/env python3
"""Write or verify `docs/catalog/CONTRACT.md`, the frozen contract (GGU-41).

The document is rendered from the projection registry, so it cannot describe a
component the backend does not serve and cannot miss one it does. This file is
the only part of the generator that touches the disk; everything it prints is
built by ``app.presentation.catalog_doc``, which is pure and covered.

Usage:
    python scripts/generate_catalog_contract.py            # write the file
    python scripts/generate_catalog_contract.py --check    # fail when stale
"""

import sys
from pathlib import Path

from app.presentation.catalog_doc import (
    CONTRACT_PATH,
    contract_document,
    contract_drift,
)
from app.presentation.registry import REGISTRY
from app.presentation.views import LOADED

REPO_ROOT = Path(__file__).resolve().parents[2]
FIX = "cd backend && make catalog"


def main(argv: list[str]) -> int:
    """Return 0 when the contract is written or already current, 1 otherwise."""
    target = REPO_ROOT / CONTRACT_PATH
    generated = contract_document(REGISTRY.all())
    if "--check" not in argv:
        target.parent.mkdir(parents=True, exist_ok=True)
        _ = target.write_text(generated, encoding="utf-8")
        print(f"wrote {CONTRACT_PATH} from {len(LOADED)} view module(s)")
        return 0
    checked_in = target.read_text(encoding="utf-8") if target.exists() else ""
    drift = contract_drift(checked_in=checked_in, generated=generated)
    if not drift:
        print(f"{CONTRACT_PATH} is current ({len(REGISTRY.all())} projections)")
        return 0
    print(drift, end="")
    print(f"\n{CONTRACT_PATH} is stale — a projection changed. Regenerate it:")
    print(f"  {FIX}")
    return 1


if __name__ == "__main__":  # pragma: no cover - CLI guard
    sys.exit(main(sys.argv[1:]))
