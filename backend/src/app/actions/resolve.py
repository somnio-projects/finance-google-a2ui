"""Turning a surface's arguments into a validated action (spec 0022 §3.1).

The mirror of ``app.presentation.resolve``, and deliberately the same shape:
one place where caller input meets a declared pydantic model, one rejection,
one message. Nothing is interpreted at runtime — an argument the action does
not declare is rejected rather than ignored, because every arguments model
forbids extras.

The message names the offending **argument** and never its value: an echoed
input is how a rejection turns into a reflection vector.
"""

from collections.abc import Mapping
from typing import Any, Final

from pydantic import BaseModel, ValidationError

from app.actions.contracts import SurfaceAction
from app.core.errors import ValidationFailedError

#: Stands in for an argument the action does not declare. Its *name* came from
#: the caller, so it is never echoed: the presentation twin can afford to name
#: an unknown option because a 422 body is ours, while this message is
#: reflected into a JSON-RPC error with a 256-character field behind it.
UNDECLARED: Final[str] = "<undeclared>"


def _offending(action: SurfaceAction, exc: ValidationError) -> list[str]:
    """Name the rejected arguments, using only names the action declares."""
    declared = set(action.args.model_fields)
    faulted = {str(error["loc"][0]) for error in exc.errors() if error["loc"]}
    return sorted({name if name in declared else UNDECLARED for name in faulted})


def validated_args(action: SurfaceAction, args: Mapping[str, Any]) -> BaseModel:
    """Validate ``args`` against ``action``'s declared arguments model.

    Args:
        action: The registered action the arguments were supplied for.
        args: Only the arguments the surface actually supplied.

    Returns:
        The action's arguments model with its defaults filled in.

    Raises:
        ValidationFailedError: When an argument is undeclared or out of range.
    """
    try:
        return action.args.model_validate(dict(args))
    except ValidationError as exc:
        msg = f"action {action.id!r} rejected argument(s) {_offending(action, exc)}"
        raise ValidationFailedError(msg) from exc


def composed_prompt(action: SurfaceAction, args: Mapping[str, Any]) -> str:
    """Validate ``args`` and return the turn input the **backend** composes.

    Args:
        action: The registered action the surface named.
        args: The scalar arguments it sent.

    Returns:
        The sentence the turn receives — a constant in backend code with
        validated arguments substituted in. The caller supplies values; it
        never supplies the sentence, the field path, the tool or the view
        (ADR-K D-3).

    Raises:
        ValidationFailedError: When an argument is undeclared or out of range.
    """
    return action.prompt(validated_args(action, args))


__all__ = ["composed_prompt", "validated_args"]
