"""Facts every catalog rendering reads off a projection (GGU-53, spec 0023).

The OpenAPI catalog, the Markdown contract, the JSON snapshot and the prompt
fragments all need the same two derived values, and each one computing its own
copy is how two artefacts come to disagree — which is exactly the defect spec
0021 §1 predicted and GGU-92 then found in the ``actions`` key.

It is a module of its own because the renderings cannot import each other
(``catalog_json`` already reads ``digest`` and ``fields_of`` from
``catalog_doc``, so the reverse direction would close a cycle) and because
``guidance`` cannot live in ``guidance.py`` either — ``registry`` imports that
module for the ``Guidance`` type, so a function there taking a ``Projection``
would be circular. One module downstream of both, four callers served.
"""

from typing import Any

from app.presentation.registry import Projection


def component_of(projection: Projection) -> str:
    """Return the A2UI component the client registers this projection under.

    The **single string the Flutter client registers against**, and therefore
    the one value two artefacts must never spell differently. It is never
    transcribed: the shipped example is validated back into the payload DTO
    and handed to the projection's own A2UI adapter, so every rendering
    carries the component the backend actually emits and the round trip proves
    the example still deserialises.

    Args:
        projection: The registered projection to ask.

    Returns:
        The catalog component name, verbatim as the adapter emits it.
    """
    payload = projection.dto.model_validate(dict(projection.example))
    return projection.surface(payload).component


def guidance_of(projection: Projection) -> dict[str, Any] | None:
    """Return the do/don't pair the model is taught, or ``None``.

    Args:
        projection: The registered projection to ask.

    Returns:
        The serialised ``Guidance``, or ``None`` for a projection whose design
        page was never exported — the honest answer rather than a sentence
        this backend wrote for itself (``presentation.guidance``).
    """
    if projection.guidance is None:
        return None
    return projection.guidance.model_dump(mode="json")


__all__ = ["component_of", "guidance_of"]
