#!/usr/bin/env python3
"""Claude Code PostToolUse hook (Edit|Write) for the backend.

Fast, file-scoped feedback: when a ``backend/**/*.py`` file is written, run
ruff (lint + format check), basedpyright on that file and the file-length
budget. Any failure exits 2 so the output is fed back to the agent as a
correction. The full test suite stays in ``make gate`` / CI.

Degrades to exit 0 for non-backend files, missing toolchain, or malformed
input — it must never block unrelated work.
"""

import json
import os
import subprocess
import sys
from pathlib import Path

MAX_LINES = 150
TIMEOUT = 90


def _read_event() -> dict:
    try:
        return json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        return {}


def main() -> int:
    """Return 0 (ok / not applicable) or 2 (findings to feed back)."""
    project = Path(os.environ.get("CLAUDE_PROJECT_DIR") or os.getcwd())
    event = _read_event()
    raw_path = (event.get("tool_input") or {}).get("file_path")
    if not raw_path or not raw_path.endswith(".py"):
        return 0
    path = Path(raw_path)
    backend = project / "backend"
    try:
        rel = path.resolve().relative_to(backend.resolve())
    except ValueError:
        return 0
    if not path.exists() or str(rel).startswith((".venv", "alembic/versions")):
        return 0
    if not (backend / ".venv").exists():
        return 0

    env = {**os.environ, "UV_LINK_MODE": "copy"}
    failures: list[str] = []

    lines = sum(1 for _ in path.open(encoding="utf-8"))
    if lines > MAX_LINES and not str(rel).startswith("alembic"):
        failures.append(f"{rel}: {lines} lines, budget is {MAX_LINES} — split the file")

    for label, args in (
        ("ruff check", ["uv", "run", "ruff", "check", str(rel)]),
        ("ruff format", ["uv", "run", "ruff", "format", "--check", str(rel)]),
        ("basedpyright", ["uv", "run", "basedpyright", str(rel)]),
    ):
        try:
            result = subprocess.run(  # noqa: S603
                args, cwd=backend, env=env, capture_output=True, text=True, timeout=TIMEOUT
            )
        except (subprocess.TimeoutExpired, FileNotFoundError):
            continue
        if result.returncode != 0:
            out = (result.stdout + result.stderr).strip()
            out = "\n".join(l for l in out.splitlines() if "trust settings" not in l)
            failures.append(f"[{label}] {rel}\n{out[-3000:]}")

    if failures:
        sys.stderr.write("[post-edit-check] backend findings:\n" + "\n\n".join(failures) + "\n")
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
