"""AC-2 — the shared DTO vocabulary every projection is built from (ADR-K D-16).

The point of a fragment is that the exact ``Decimal`` and the string the
client binds travel together: a widget plots one and prints the other, and
neither is recomputed downstream.
"""

from decimal import Decimal

import pytest
from pydantic import ValidationError

from app.presentation.fragments import (
    Annotation,
    Bucket,
    Category,
    Series,
    SeriesPoint,
    Total,
    money,
    percentage,
)
from app.presentation.surfaces import Surface


def test_money_pairs_the_exact_decimal_with_its_display() -> None:
    pair = money(Decimal("26985.005"))
    assert pair.amount == Decimal("26985.005")  # unrounded, for charting
    assert pair.display == "$26,985.00"


def test_percentage_pairs_the_exact_ratio_with_its_display() -> None:
    pair = percentage(Decimal("0.5927249"))
    assert pair.value == Decimal("0.5927249")
    assert pair.display == "59.27%"


def test_fragments_compose_into_the_shapes_a_widget_binds() -> None:
    total = Total(label="Total market value", amount=money(Decimal("100")))
    category = Category(
        key="BTC",
        label="Bitcoin",
        value=money(Decimal("60")),
        weight=percentage(Decimal("0.6")),
    )
    bucket = Bucket(
        key="BTC",
        label="Bitcoin",
        delta=money(Decimal("10")),
        cumulative=money(Decimal("110")),
        direction="up",
    )
    series = Series(
        name="BTC",
        points=(
            SeriesPoint(
                at=money(Decimal("64000")),
                label="$64,000.00",
                value=money(Decimal("64250")),
            ),
        ),
    )
    note = Annotation(label="Net", text="$10.00")
    assert (total.amount.display, category.weight.display) == ("$100.00", "60.00%")
    assert (bucket.direction, series.points[0].value.display) == ("up", "$64,250.00")
    assert note.text == "$10.00"
    # The pair a painter needs: `at` places the point, `label` prints the tick.
    assert (series.points[0].at.amount, series.points[0].at.display) == (
        Decimal("64000"),
        "$64,000.00",
    )
    # A segment's key is the value a tap sends back, never its prose label.
    assert (bucket.key, bucket.label) == ("BTC", "Bitcoin")


def test_fragments_are_frozen() -> None:
    total = Total(label="Total", amount=money(Decimal("1")))
    with pytest.raises(ValidationError, match="frozen"):
        total.label = "other"


def test_bucket_direction_is_bounded_to_up_or_down() -> None:
    with pytest.raises(ValidationError, match="direction"):
        Bucket(
            key="BTC",
            label="Bitcoin",
            delta=money(Decimal("1")),
            cumulative=money(Decimal("1")),
            direction="sideways",  # pyright: ignore[reportArgumentType]
        )


def test_surface_carries_the_component_and_its_props() -> None:
    surface = Surface(
        component="HoldingsSummary",
        view="holdings.allocation.v1",
        title="Allocation",
        props={"slices": []},
    )
    assert surface.model_dump(mode="json")["props"] == {"slices": []}
