#!/usr/bin/env python3
"""Fail when any source or test file exceeds the line budget.

Small files are a design constraint here, not a style preference: a module
that needs more than ``MAX_LINES`` lines is doing more than one thing.
Usage: ``python scripts/check_file_budget.py [paths...]`` (defaults to src/ tests/).
"""

import sys
from pathlib import Path

MAX_LINES = 150
DEFAULT_ROOTS = ("src", "tests", "alembic/env.py")
SKIP_PARTS = {".venv", "__pycache__", "versions"}


def _candidates(roots: list[str]) -> list[Path]:
    files: list[Path] = []
    for root in roots:
        path = Path(root)
        if path.is_file():
            files.append(path)
            continue
        files.extend(
            p for p in path.rglob("*.py") if not SKIP_PARTS.intersection(p.parts)
        )
    return files


def main(argv: list[str]) -> int:
    """Return 0 when every file is within budget, 1 otherwise."""
    roots = argv or list(DEFAULT_ROOTS)
    offenders: list[tuple[Path, int]] = []
    for path in _candidates(roots):
        lines = sum(1 for _ in path.open(encoding="utf-8"))
        if lines > MAX_LINES:
            offenders.append((path, lines))
    for path, lines in sorted(offenders, key=lambda item: -item[1]):
        print(f"{path}: {lines} lines (budget {MAX_LINES})")
    if offenders:
        print(f"{len(offenders)} file(s) over budget — split them.")
        return 1
    print(f"file budget ok ({MAX_LINES} lines)")
    return 0


if __name__ == "__main__":  # pragma: no cover - CLI guard
    sys.exit(main(sys.argv[1:]))
