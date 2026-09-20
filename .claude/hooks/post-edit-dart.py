#!/usr/bin/env python3
"""Claude Code PostToolUse hook (Edit|Write) for the frontend.

The Dart counterpart of ``post-edit-check.py``. When a ``frontend/**/*.dart``
file is written, run the file-length budget, ``dart format`` and ``dart
analyze`` scoped to that file. Any failure exits 2 so the output is fed back to
the agent as a correction. The full suite stays in ``make gate`` / CI.

Degrades to exit 0 for non-frontend files, a missing toolchain, an unresolved
workspace, or malformed input — it must never block unrelated work.
"""

import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

MAX_LINES = 150
TIMEOUT = 90
GENERATED_SUFFIXES = (".g.dart", ".freezed.dart")


def _read_event() -> dict:
    try:
        return json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        return {}


def _budget(path: Path, rel: Path) -> list[str]:
    if str(rel).endswith(GENERATED_SUFFIXES):
        return []
    lines = sum(1 for _ in path.open(encoding="utf-8"))
    if lines <= MAX_LINES:
        return []
    return [f"{rel}: {lines} lines, budget is {MAX_LINES} — split the file"]


def main() -> int:
    """Return 0 (ok / not applicable) or 2 (findings to feed back)."""
    project = Path(os.environ.get("CLAUDE_PROJECT_DIR") or os.getcwd())
    event = _read_event()
    raw_path = (event.get("tool_input") or {}).get("file_path")
    if not raw_path or not raw_path.endswith(".dart"):
        return 0
    path = Path(raw_path)
    frontend = project / "frontend"
    try:
        rel = path.resolve().relative_to(frontend.resolve())
    except ValueError:
        return 0
    if not path.exists():
        return 0
    # Without a resolved workspace the analyzer reports every import as
    # missing, which would be noise rather than a finding.
    if not (frontend / ".dart_tool" / "package_config.json").exists():
        return 0
    if shutil.which("dart") is None:
        return 0

    failures = _budget(path, rel)
    for label, args in (
        ("dart format", ["dart", "format", "--output=none",
                         "--set-exit-if-changed", str(rel)]),
        ("dart analyze", ["dart", "analyze", "--fatal-infos",
                          "--fatal-warnings", str(rel)]),
    ):
        try:
            result = subprocess.run(  # noqa: S603
                args, cwd=frontend, capture_output=True, text=True,
                timeout=TIMEOUT, check=False,
            )
        except (subprocess.TimeoutExpired, FileNotFoundError, OSError):
            continue
        if result.returncode != 0:
            out = (result.stdout + result.stderr).strip()
            failures.append(f"[{label}] {rel}\n{out[-3000:]}")

    if failures:
        sys.stderr.write(
            "[post-edit-dart] frontend findings:\n" + "\n\n".join(failures) + "\n"
        )
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
