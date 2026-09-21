"""The A2UI component name a projection is registered under.

Extracted from ``catalog_json`` so that ``contract`` can publish it on
``GET /v1/views`` as well. It cannot live in either of those: ``catalog_doc``
imports ``contract``, so ``contract`` importing ``catalog_json`` would close a
cycle. The function depends on nothing but a ``Projection``.
"""

from app.presentation.registry import Projection


def component_of(projection: Projection) -> str:
    """Return the A2UI component the client registers this projection under.

    The name is never transcribed into this module: the shipped example is
    validated back into the payload DTO and handed to the projection's own
    A2UI adapter, so the snapshot carries the component the backend actually
    emits (``DonutChart``, ``WaterfallChart``) and the round trip proves the
    example still deserialises.

    Args:
        projection: The registered projection to ask.

    Returns:
        The catalog component name, verbatim as the adapter emits it.
    """
    payload = projection.dto.model_validate(dict(projection.example))
    return projection.surface(payload).component


__all__ = ["component_of"]
