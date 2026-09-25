"""Spec 0033 OD-1/OD-2 — how a prompt is keyed and how a hole is filled."""

import pytest

from app.infra.model.script import TOOLS_FAILED_MESSAGE, fill, flatten, normalise

RESULT = {
    "asOf": "2026-09-18T12:00:00+00:00",
    "summary": {"proceedsDisplay": "$20,000.00", "shortTermLots": 0},
    "lots": [{"lotId": "lot-btc-01"}],
    "trend": "up",
}


@pytest.mark.parametrize(
    ("prompt", "expected"),
    [
        ("What moved my portfolio today?", "what moved my portfolio today"),
        ("  what   MOVED my portfolio today ", "what moved my portfolio today"),
        ("what moved my portfolio today!", "what moved my portfolio today"),
        ("keep it diversified.", "keep it diversified"),
        (
            "If I sell $20k of BTC, what's the tax hit?",
            "if i sell $20k of btc, what's the tax hit",
        ),
    ],
    ids=[
        "as-designed",
        "case-and-whitespace",
        "other-punctuation",
        "full-stop",
        "inner-punctuation-kept",
    ],
)
def test_normalise_forgives_case_whitespace_and_terminal_punctuation(
    prompt: str, expected: str
) -> None:
    assert normalise(prompt) == expected


def test_normalise_does_not_forgive_a_paraphrase() -> None:
    assert normalise("What moved my portfolio?") != normalise(
        "What moved my portfolio today?"
    )


def test_flatten_keeps_string_leaves_under_dotted_paths_and_nothing_else() -> None:
    assert flatten(RESULT) == {
        "asOf": "2026-09-18T12:00:00+00:00",
        "summary.proceedsDisplay": "$20,000.00",
        "trend": "up",
    }


def test_fill_copies_the_tools_strings_into_the_holes() -> None:
    sentence = fill("Raises {summary.proceedsDisplay}; trend {trend}.", [RESULT])

    assert sentence == "Raises $20,000.00; trend up."


def test_fill_lets_a_later_result_win_a_shared_path() -> None:
    first = {"changeDisplay": "+$1.00"}
    second = {"changeDisplay": "+$2.00"}

    assert fill("{changeDisplay}", [first, second]) == "+$2.00"


def test_fill_leaves_a_template_without_holes_alone() -> None:
    assert fill("Nothing is traded.", []) == "Nothing is traded."


@pytest.mark.parametrize(
    "template",
    ["{missingDisplay}", "{summary.shortTermLots} lots", "{lots}"],
    ids=["absent-field", "integer-leaf", "list-leaf"],
)
def test_fill_answers_the_fallback_when_any_hole_has_no_string(template: str) -> None:
    assert fill(f"Some words, then {template}.", [RESULT]) == TOOLS_FAILED_MESSAGE


def test_fill_answers_the_fallback_it_was_given() -> None:
    assert fill("{missing}", [{"error": "tool-failed"}], fallback="no") == "no"
