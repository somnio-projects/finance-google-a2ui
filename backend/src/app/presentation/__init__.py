"""Presentation layer — named, versioned projections (spec 0005, ADR-K).

Everything the client renders is shaped here. A projection is a **pure**
function *(portfolio, options) → DTO*, registered from its own module under a
versioned id, and the registry publishes it to four consumers at once: the
OpenAPI document, the ``GET /v1/views`` catalog, the prompt fragments GGU-14
feeds the model, and the A2UI surface adapter.

Framework-free, like ``app.core`` and ``app.domain``: stdlib, pydantic,
``app.core`` and ``app.domain`` only. Nothing here imports ``api``,
``services``, ``repositories``, ``models``, ``infra`` or ``auth``, and
``datetime.now()`` appears nowhere — a projection performs no I/O and reads no
clock (ADR-K D-6).
"""

__all__: list[str] = []
