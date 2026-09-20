"""The agent host's inner layer: the tool contract, the registry and the prompt.

``app.agent`` sits beside ``app.domain``: framework-free, importing only
stdlib, pydantic, ``app.core`` and ``app.domain``. The turn loop that drives it
is a service (``app.services.agent_service``); nothing here knows about HTTP,
sessions or SQLAlchemy.
"""

__all__: list[str] = []
