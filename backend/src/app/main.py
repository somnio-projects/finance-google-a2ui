"""ASGI entry point: ``uvicorn app.main:app``.

Excluded from coverage on purpose — it only calls the factory with the
process environment, which every integration test already exercises through
``create_app`` with explicit settings.
"""

from app.bootstrap import create_app

app = create_app()

__all__ = ["app"]
