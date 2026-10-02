"""GGU-122 AC-2 — no rendered payload calls a coin a share (spec 0046).

The portfolio is crypto (spec 0044), and equity vocabulary survived that change
in places a ticker grep cannot see: a composed sentence (``2.1 sh · avg
$41,698.00``), a tile label (``Shares``) and a **field name** (``shares``). So
this file does not grep the source — it renders **every registered projection**
and walks the payload, keys and string values alike, reporting the field path
of every hit.

Three things this file is deliberately careful about, each a defect it was
written in response to (`.claude/rules/ci-conventions.md` §5, question 2):

* **It renders, rather than requests.** The first sweep that found GGU-122 sent
  an undeclared option, so all twelve views answered 422 and the sweep counted
  matches in *error bodies* while reporting the payloads clean.
* **It includes abbreviations.** The second sweep's pattern was
  ``shares?|stocks?|…`` and `sh` is not in it, so the Holdings tab and the
  attribution card were reported clean while every row of both carried it.
* **It cannot pass vacuously.** The set of views it rendered is compared
  against ``tests.catalog.SHIPPED_VIEWS`` — a list written down *outside* the
  registry — a floor is asserted on the number of strings walked, and
  ``test_the_scanner_reports_the_field_path_of_a_planted_hit`` shows the
  scanner rejecting. A check that has never been seen to reject is the same
  defect one level up.
"""

import re
from collections.abc import Iterator
from typing import Any, Final

from app.presentation.registry import REGISTRY
from tests.catalog import SHIPPED_VIEWS

#: The equity words a crypto payload may not contain, **as whole words** and
#: including the abbreviations the first two sweeps missed. ``_`` counts as a
#: word character, so ``day_share`` is not a hit and a field literally named
#: ``shares`` is — which is the half of GGU-123 that breaks the client.
FORBIDDEN: Final[re.Pattern[str]] = re.compile(
    # The first alternative is `sh` and its plural, written with an explicit
    # group so that the plural never appears in this file as a bare word:
    # codespell reads it as a misspelling of `ssh`, and `repo.spelling` is a
    # repo-wide gate one test has no business weakening for itself.
    r"\b(?:sh(?:s)?|shares?|stocks?|equit(?:y|ies)|dividends?|tickers?)\b",
    re.IGNORECASE,
)

#: Below this many strings walked, the sweep is not believable — the shape
#: ``scripts/check_spelling.sh`` uses to refuse an implausibly small file list.
#: The twelve shipped payloads carry an order of magnitude more than this.
PLAUSIBLE_STRINGS: Final[int] = 200


def strings(node: Any, path: str = "") -> Iterator[tuple[str, str]]:
    """Yield ``(field path, text)`` for every key and string value under ``node``.

    Args:
        node: A JSON-shaped fragment of a rendered payload.
        path: The dotted path that reached ``node``.

    Yields:
        The path of each mapping key and each string leaf, with its text. Keys
        are yielded as well as values because a *field name* is part of the
        contract: ``attribution.driver.v1``'s tile was called ``shares``, and
        renaming it is what breaks a client.
    """
    if isinstance(node, dict):
        for key, value in node.items():  # pyright: ignore[reportUnknownVariableType]
            here = f"{path}.{key}" if path else str(key)
            yield here, str(key)
            yield from strings(value, here)
    elif isinstance(node, list):
        for index, value in enumerate(node):  # pyright: ignore[reportUnknownVariableType]
            yield from strings(value, f"{path}[{index}]")
    elif isinstance(node, str):
        yield path, node


def rendered() -> dict[str, dict[str, Any]]:
    """Render every registered projection over the sample portfolio."""
    return {projection.id: dict(projection.example) for projection in REGISTRY.all()}


def hits(payloads: dict[str, dict[str, Any]]) -> list[str]:
    """Report ``view · path · text`` for every forbidden word found."""
    return [
        f"{view} · {path} · {text!r} (matched {found.group(0)!r})"
        for view, payload in payloads.items()
        for path, text in strings(payload)
        if (found := FORBIDDEN.search(text)) is not None
    ]


def test_every_shipped_view_is_rendered_before_anything_is_asserted() -> None:
    """Anti-vacuity — the sweep's subject is the whole shipped catalog.

    ``SHIPPED_VIEWS`` is written down rather than read from ``REGISTRY``, so a
    projection that fails to render, or one added without being named there,
    fails here by name instead of quietly narrowing the sweep below.
    """
    assert tuple(sorted(rendered())) == tuple(sorted(SHIPPED_VIEWS))


def test_the_sweep_walks_a_plausible_number_of_strings() -> None:
    """Anti-vacuity — an empty or shallow walk cannot report a clean result."""
    walked = [pair for payload in rendered().values() for pair in strings(payload)]

    assert len(walked) >= PLAUSIBLE_STRINGS


def test_the_scanner_reports_the_field_path_of_a_planted_hit() -> None:
    """The scanner is shown **rejecting**, on the exact strings GGU-122 found.

    Every form the live sweep met is planted at once: the abbreviation inside a
    composed sentence, a tile label, a field name, and one inside a list.
    """
    planted = {
        "planted.v1": {
            "positions": [{"detail": "2.1 sh · avg $41,698.00"}],
            "impact": {"units": {"label": "Est. shares"}},
            "shares": {"label": "Units"},
            "clean": {"day_share": {"caption": "of +$2,201.05"}},
        }
    }

    reported = hits(planted)

    assert sorted(reported) == sorted(
        [
            "planted.v1 · positions[0].detail · '2.1 sh · avg $41,698.00' "
            "(matched 'sh')",
            "planted.v1 · impact.units.label · 'Est. shares' (matched 'shares')",
            "planted.v1 · shares · 'shares' (matched 'shares')",
        ]
    )


def test_no_rendered_payload_uses_equity_vocabulary() -> None:
    """AC-2 — the sweep itself, over every shipped payload."""
    found = hits(rendered())

    assert found == [], "equity vocabulary in a crypto payload:\n" + "\n".join(found)
