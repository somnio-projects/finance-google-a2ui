"""What a scripted turn is made of (spec 0033).

A ``Script`` is one row of the demo's table: the tool calls a prompt runs, and
the sentence said once their results are back. The sentence is **server
text with holes**, and a hole may be filled by exactly one kind of thing — a
string a tool returned in this turn, named by its dotted path
(``{summary.proceedsDisplay}``). The invariant this keeps is the product's
own: every figure in the answer is a verbatim copy of a ``*Display`` field,
because nothing else can reach the template (ADR-E D-2, spec 0006 AC-8).

When a hole cannot be filled — the tool refused, raised, or the field is not a
string — the whole answer is replaced by ``TOOLS_FAILED_MESSAGE``. A sentence
with a figure missing from it is not a sentence to send half of.
"""

import re
from collections.abc import Iterable, Mapping
from dataclasses import dataclass
from typing import Final, cast

TOOLS_FAILED_MESSAGE: Final[str] = (
    "The tools could not complete that request, so there is nothing to show yet."
)

#: A hole names a field of a tool result by its dotted path. Only a string
#: leaf fills one, which is what keeps every figure a copy (spec 0033 OD-2).
PLACEHOLDER: Final[re.Pattern[str]] = re.compile(r"\{([A-Za-z0-9_.]+)\}")

#: What a person types after the last word and still means the same question.
_TERMINAL_PUNCTUATION: Final[str] = ".?!"


@dataclass(frozen=True, slots=True)
class ScriptedCall:
    """One tool call a script asks the turn to make, arguments included."""

    name: str
    arguments: Mapping[str, object]


@dataclass(frozen=True, slots=True)
class Script:
    """The turn one prompt runs: at least one call, then one sentence.

    Attributes:
        calls: The tool calls, in the order their surfaces should appear.
            Never empty — a script with nothing to call would answer with an
            empty reply and spend the iteration bound repeating it.
        answer: The sentence said once every call has returned, with holes
            for the tool's own strings.
    """

    calls: tuple[ScriptedCall, ...]
    answer: str


def normalise(prompt: str) -> str:
    """Return ``prompt`` as the table keys it (spec 0033 OD-1).

    Case, runs of whitespace and terminal punctuation are the ways a typed
    question differs from the design's sentence without asking anything else;
    nothing further is forgiven, so a paraphrase misses on purpose.

    Args:
        prompt: What the user typed, or what an action composed.

    Returns:
        The key to look up.
    """
    return " ".join(prompt.casefold().split()).rstrip(_TERMINAL_PUNCTUATION)


def flatten(result: Mapping[str, object], prefix: str = "") -> dict[str, str]:
    """Return every string leaf of ``result`` under its dotted path.

    Args:
        result: One tool result, as the loop fed it back.
        prefix: The path of the mapping being walked, for recursion.

    Returns:
        ``{"summary.proceedsDisplay": "$20,000.00", ...}``. Lists are skipped:
        a row of a table is drawn, never quoted, and a count is not a figure.
    """
    values: dict[str, str] = {}
    for key, value in result.items():
        path = f"{prefix}{key}"
        if isinstance(value, str):
            values[path] = value
        elif isinstance(value, Mapping):
            nested = cast("Mapping[str, object]", value)
            values.update(flatten(nested, f"{path}."))
    return values


def fill(
    template: str,
    results: Iterable[Mapping[str, object]],
    *,
    fallback: str = TOOLS_FAILED_MESSAGE,
) -> str:
    """Return ``template`` with every hole filled from ``results``.

    Args:
        template: The script's sentence.
        results: The tool results of this turn, oldest first; a later result
            wins a path two of them share.
        fallback: What to say when a hole has nothing to fill it.

    Returns:
        The sentence, or ``fallback`` when any hole is unfilled — an answer
        never carries a figure the tools did not return, and never a bracket.
    """
    values: dict[str, str] = {}
    for result in results:
        values.update(flatten(result))
    try:
        return PLACEHOLDER.sub(lambda match: values[match.group(1)], template)
    except KeyError:
        return fallback


__all__ = [
    "PLACEHOLDER",
    "TOOLS_FAILED_MESSAGE",
    "Script",
    "ScriptedCall",
    "fill",
    "flatten",
    "normalise",
]
