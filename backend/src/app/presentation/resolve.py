"""Turning a caller's options into a validated render (ADR-K D-3, D-12).

Both callers land here — the client through ``?view=`` and the model through a
render intent — so an option is judged once, by the projection's own model, and
the answer is the same on both paths. Nothing is interpreted at runtime: an
option the projection does not declare is rejected, never ignored, because
every options model forbids extras.

The message names the offending option and never its value: an echoed input is
how a rejection turns into a reflection vector.
"""

from collections.abc import Mapping
from typing import Any

from pydantic import BaseModel, ValidationError

from app.core.errors import ValidationFailedError
from app.presentation.registry import Projection


def validated_options(projection: Projection, options: Mapping[str, Any]) -> BaseModel:
    """Validate ``options`` against ``projection``'s declared options model.

    Args:
        projection: The projection the options were supplied for.
        options: Only the options the caller actually supplied.

    Returns:
        The projection's options model with its defaults filled in.

    Raises:
        ValidationFailedError: When an option is undeclared or out of range.
    """
    try:
        return projection.options.model_validate(dict(options))
    except ValidationError as exc:
        names = sorted({".".join(str(part) for part in e["loc"]) for e in exc.errors()})
        msg = f"view {projection.id!r} rejected option(s) {names}"
        raise ValidationFailedError(msg) from exc


__all__ = ["validated_options"]
