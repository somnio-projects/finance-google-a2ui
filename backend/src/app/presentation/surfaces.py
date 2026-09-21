"""The A2UI indirection — one adapter per projection, in one type (ADR-K D-14).

``genui``, ``genui_a2a`` and ``a2ui_core`` are alpha and their component
catalog will move. Keeping the mapping from payload to component in a single
adapter per projection is what makes a library bump a contained change instead
of a sweep through business code: the projections keep their shape, only the
adapters follow the catalog.
"""

from typing import Any

from pydantic import BaseModel, ConfigDict, Field


class Surface(BaseModel):
    """One A2UI surface: the component to instantiate and the props to bind."""

    model_config = ConfigDict(frozen=True)

    component: str = Field(
        max_length=64,
        description=(
            "Catalog component the client instantiates. It is the one string "
            "the Flutter client registers against, so it is named by the "
            "design catalog's own A2UI schema block and nowhere else "
            "(GGU-53); `test_component_names.py` compares the four places it "
            "is written down."
        ),
        examples=["AllocationSummary"],
    )
    view: str = Field(
        max_length=64,
        description="Projection this surface was rendered from.",
        examples=["holdings.allocation.v1"],
    )
    title: str = Field(
        max_length=120,
        description="Title the component shows.",
        examples=["Allocation by holding"],
    )
    props: dict[str, Any] = Field(
        description=(
            "Component properties, already formatted. The client binds them; "
            "it computes nothing and formats nothing."
        ),
        examples=[{"centerValue": "$86,318.85"}],
    )


__all__ = ["Surface"]
