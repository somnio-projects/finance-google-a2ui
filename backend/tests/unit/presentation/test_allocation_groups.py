"""GGU-145 — the donut publishes the groupings its toggle switches between.

The design draws a segmented control and `group_by` was already the option
behind it; what the payload lacked was the choices and a word for each. These
hold the three claims that makes: every declared value has a label, exactly
one is marked, and what the client sends back is a value the option accepts.
"""

import pytest

from app.domain.portfolio import Portfolio
from app.presentation.allocation_groups import GROUP_LABELS, choices
from app.presentation.allocation_options import HoldingsAllocationOptions
from app.presentation.allocation_rows import GroupBy
from app.presentation.views.holdings_allocation import render

#: The option's own enum, read from the model rather than restated here.
DECLARED: tuple[str, ...] = tuple(
    HoldingsAllocationOptions.model_json_schema()["properties"]["group_by"]["enum"]
)


def test_every_declared_grouping_has_a_word_to_show() -> None:
    """Two declarations of one fact, compared.

    The option's enum and the label table are written in different modules,
    and a grouping added to one and forgotten in the other would reach a
    client as a blank segment — the shape `.claude/rules/backend/testing.md`
    names as the hole that hides between two declarations.
    """
    assert set(GROUP_LABELS) == set(DECLARED)


def test_the_toggle_offers_every_grouping_in_one_order() -> None:
    """N-10 applies to the client, so the sequence is decided here."""
    assert [choice.value for choice in choices("holding")] == list(GROUP_LABELS)


@pytest.mark.parametrize("selected", DECLARED, ids=DECLARED)
def test_exactly_one_segment_is_marked_and_it_is_the_one_asked_for(
    selected: str,
) -> None:
    """A toggle with two segments lit, or none, is not a toggle."""
    marked = [choice for choice in choices(selected) if choice.selected]  # type: ignore[arg-type]

    assert [choice.value for choice in marked] == [selected]


def test_the_card_marks_the_grouping_it_actually_rendered(
    portfolio: Portfolio,
) -> None:
    """The mark and the slices cannot disagree.

    Asserted against `payload.group_by` rather than against a literal: the
    claim is that the segment lit is the grouping the donut was drawn with,
    which is a relationship between two fields of one payload.
    """
    payload = render(portfolio, HoldingsAllocationOptions(group_by="sector"))
    marked = [choice for choice in payload.groups if choice.selected]

    assert [choice.value for choice in marked] == [payload.group_by]


@pytest.mark.parametrize("value", DECLARED, ids=DECLARED)
def test_what_the_client_sends_back_is_an_option_the_view_accepts(
    portfolio: Portfolio, value: str
) -> None:
    """The round trip the toggle is for.

    Every published `value` is fed back through the projection's **own**
    options model, so a segment the client could tap and the server would
    then reject with a 422 fails here instead.
    """
    default = render(portfolio, HoldingsAllocationOptions())
    published = {choice.value for choice in default.groups}
    asked = HoldingsAllocationOptions(group_by=value)  # type: ignore[arg-type]

    assert value in published
    assert render(portfolio, asked).group_by == value


def test_a_label_is_never_a_bare_enum_value() -> None:
    """The words are for a reader, which is why the server writes them.

    `asset_class` reaching a segment would be the client showing an
    identifier — and a client that prettified it would be authoring copy for
    a value the server owns (N-1).
    """
    for value, label in GROUP_LABELS.items():
        assert label != value
        assert label.startswith("By ")


def test_the_grouping_type_and_the_label_table_agree_statically() -> None:
    """`GroupBy` is the type the rest of the package passes around."""
    assert set(GROUP_LABELS) == set(GroupBy.__args__)  # type: ignore[attr-defined]
