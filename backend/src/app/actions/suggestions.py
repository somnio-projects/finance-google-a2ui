"""The curated entry chips: a key, the words shown, and the turn they start.

**The chip's sentence lives here, in backend code, keyed by a declared id.**
The payload publishes ``{id, label}``; the surface sends the id back; the turn
receives the text from this table, verbatim. That is ADR-K D-12 applied to
chips — *the model picks from the registry, it never invents* — and it has two
consequences worth stating rather than discovering:

* a chip whose sentence the model authored would be model-generated text
  re-entering the turn as a **user** message, which is exactly the shape this
  project refuses to ship as a reference implementation;
* a tap is reproducible, because the label a person read and the prompt that
  ran cannot drift apart.

Stated plainly, and recorded as spec 0022 OD-1: **the agent cannot invent a
follow-up chip.** It selects from this table. That closes GGU-32's
"agent-generated dynamic follow-ups" stretch until the spec is amended.
"""

from typing import Final, Literal, get_args

#: The keys a surface may send back. The ``Literal`` is the bound the arguments
#: model enforces; ``SUGGESTIONS`` is the text each key runs. A test compares
#: the two, so a key added to one and forgotten in the other fails the gate.
SuggestionKey = Literal[
    "allocation",
    "biggest-drivers",
    "tax-lots",
    "why-did-i-move",
]

#: Suggestion key → (label shown on the chip, prompt the turn receives).
SUGGESTIONS: Final[dict[str, tuple[str, str]]] = {
    "allocation": (
        "What do I hold?",
        "Show me what I hold and how my portfolio is allocated.",
    ),
    "biggest-drivers": (
        "Biggest drivers",
        "Which holdings drove my performance the most over the last week?",
    ),
    "tax-lots": (
        "Tax lots",
        "Show me the tax lots a sale would consume and what it would realise.",
    ),
    "why-did-i-move": (
        "Why did I move?",
        "Why did my portfolio move over the last week?",
    ),
}

#: Every key the ``Literal`` admits, for the test that compares the two.
DECLARED_KEYS: Final[tuple[str, ...]] = get_args(SuggestionKey)


def suggestion_label(key: str) -> str:
    """Return the words the chip for ``key`` shows."""
    return SUGGESTIONS[key][0]


def suggestion_prompt(key: str) -> str:
    """Return the registered prompt ``key`` runs, byte for byte."""
    return SUGGESTIONS[key][1]


__all__ = [
    "DECLARED_KEYS",
    "SUGGESTIONS",
    "SuggestionKey",
    "suggestion_label",
    "suggestion_prompt",
]
