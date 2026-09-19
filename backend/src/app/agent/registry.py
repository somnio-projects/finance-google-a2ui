"""The tool registry, filled by local registration (spec 0006 AC-7, ADR-K D-7).

Adding a tool must never edit a shared file — no central list, no enum, no
``if/elif`` chain. A tool module ends with ``register(MyTool())`` and
``load_tools()`` imports every module in ``app.agent.tools`` so that line runs.
Discovery is ``pkgutil``, which means the only thing a new tool touches is its
own module and its own test.

That is the same seam ADR-K D-15 demands for projections: a design that needs
a shared file edited to add one is a failed implementation of it.
"""

import pkgutil
from importlib import import_module
from typing import Final

from app.agent.contracts import Tool
from app.core.errors import ConfigurationError
from app.core.model import ToolSpec

TOOLS_PACKAGE: Final[str] = "app.agent.tools"


class ToolRegistry:
    """The tools one agent host may call, keyed by the name the model uses."""

    def __init__(self) -> None:
        """Create an empty registry."""
        self._tools: dict[str, Tool] = {}

    def register(self, tool: Tool) -> None:
        """Add ``tool`` under its own name.

        Args:
            tool: The tool instance to publish to the model.

        Raises:
            ConfigurationError: When that name is already registered — two
                tools answering to one name is a startup bug, not a runtime
                one, so it fails before the first request.
        """
        if tool.name in self._tools:
            msg = f"tool {tool.name!r} is already registered"
            raise ConfigurationError(msg)
        self._tools[tool.name] = tool

    def get(self, name: str) -> Tool | None:
        """Return the tool called ``name``, or ``None`` when there is none.

        A missing tool is deliberately not an exception: the model may
        hallucinate a name, and that is a turn-level event the loop answers
        with an error result rather than a failed request.

        Args:
            name: The tool name exactly as the model wrote it.

        Returns:
            The registered tool, or ``None``.
        """
        return self._tools.get(name)

    def specs(self) -> tuple[ToolSpec, ...]:
        """Return every registered tool as a model-facing schema, name-sorted.

        Returns:
            The specs in a stable order, so two identical turns send the model
            an identical prompt.
        """
        return tuple(
            ToolSpec(
                name=tool.name,
                description=tool.description,
                parameters=tool.parameters,
            )
            for tool in sorted(self._tools.values(), key=lambda item: item.name)
        )

    def names(self) -> tuple[str, ...]:
        """Return the registered tool names in sorted order."""
        return tuple(sorted(self._tools))


REGISTRY: Final[ToolRegistry] = ToolRegistry()


def register(tool: Tool) -> Tool:
    """Publish ``tool`` to the process registry from the tool's own module.

    Args:
        tool: The instance to register.

    Returns:
        The same instance, so a module can keep a reference to it.
    """
    REGISTRY.register(tool)
    return tool


def load_tools() -> ToolRegistry:
    """Import every module of ``app.agent.tools`` so each one registers itself.

    Returns:
        The process registry, now populated. Idempotent: a module already in
        ``sys.modules`` is not re-executed, so calling this twice does not
        trip the duplicate-name guard.
    """
    # Imported here, not at module scope: the tool modules import this one.
    from app.agent import tools as package

    for module in pkgutil.iter_modules(package.__path__):
        import_module(f"{TOOLS_PACKAGE}.{module.name}")
    return REGISTRY


__all__ = ["REGISTRY", "TOOLS_PACKAGE", "ToolRegistry", "load_tools", "register"]
