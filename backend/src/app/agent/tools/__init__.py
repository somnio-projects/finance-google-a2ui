"""Deterministic tools the agent may call — one module per tool.

This package is a **discovery target**, not an index: ``load_tools()`` imports
every module found here, and each module registers its own tool on import. Do
not add imports, an ``__all__`` of tool names or any other list to this file —
the whole point is that adding a tool touches nothing but its own module
(spec 0006 AC-7, ADR-K D-7/D-15).
"""

__all__: list[str] = []
