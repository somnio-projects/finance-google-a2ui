"""What a v1.0 renderer says it can draw (ADR-M D-8, extension spec).

A renderer attaches ``a2uiRendererCapabilities`` to the ``metadata`` of every
message. This agent reads one fact from it — whether the finance catalog is
among the catalogs the renderer supports — and refuses the call when it is not,
rather than streaming surfaces nothing on the other side can draw.
"""

from pydantic import BaseModel, ConfigDict, Field


class RendererV1Capabilities(BaseModel):
    """The ``v1.0`` member of ``a2uiRendererCapabilities``."""

    model_config = ConfigDict(frozen=True, extra="ignore", populate_by_name=True)

    supported_catalog_ids: tuple[str, ...] = Field(
        alias="supportedCatalogIds",
        max_length=16,
        description="Catalog ids the renderer can draw; must include this agent's.",
    )


class RendererCapabilities(BaseModel):
    """``a2uiRendererCapabilities``: what the renderer can draw, per version."""

    model_config = ConfigDict(frozen=True, extra="ignore", populate_by_name=True)

    v1: RendererV1Capabilities | None = Field(
        default=None, alias="v1.0", description="Capabilities for A2UI v1.0."
    )


class MessageMetadata(BaseModel):
    """The message ``metadata`` keys this agent reads."""

    model_config = ConfigDict(frozen=True, extra="ignore", populate_by_name=True)

    capabilities: RendererCapabilities | None = Field(
        default=None,
        alias="a2uiRendererCapabilities",
        description="What the renderer can draw (ADR-M D-8).",
    )

    def catalogs(self) -> tuple[str, ...]:
        """Return the catalog ids declared for v1.0, or none at all."""
        if self.capabilities is None or self.capabilities.v1 is None:
            return ()
        return self.capabilities.v1.supported_catalog_ids


__all__ = ["MessageMetadata", "RendererCapabilities", "RendererV1Capabilities"]
