"""Simulated portfolio domain (spec 0003) — the backend's source of numbers.

Framework-free, like ``app.core``: stdlib, pydantic and ``app.core`` only.
Nothing here imports ``api``, ``services``, ``repositories``, ``models``,
``infra`` or ``auth``, and ``datetime.now()`` appears nowhere — every instant
arrives through the injected ``Clock`` (ADR-F D-6).
"""

__all__: list[str] = []
