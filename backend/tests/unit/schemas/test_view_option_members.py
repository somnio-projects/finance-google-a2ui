"""The endpoint's enums and the projections' enums are the same sets.

`test_view_query_accepts_every_registered_option` compares option **names**:
it catches an option a projection declares and the endpoint does not, which
is the GGU-41 gap. It says nothing at all about **members**, and the two
declarations of each closed set live in different layers:

| The endpoint declares | The projection declares |
|---|---|
| `view_options_tabs.AssetClassFilter` | `positions_payload.AssetFilter` |
| `view_options_tabs.ActivityKind` | `activity_payload.Kind` |
| `view_options_tabs.GroupBy` | `allocation_options.GroupBy` |
| `view_options.LotMethod` | `domain.lot_selection`'s methods |

Add a member to one side only and the failure is silent in the direction
that matters: the catalog advertises a value the endpoint answers **422**
for, or the endpoint accepts one the projection then rejects. Neither is a
crash and neither is covered by a names-only comparison — spec 0035 §3 calls
these "the same closed set", and until this file existed that sentence was a
comment rather than a check.

Mutation checked: add `"crypto"` to `AssetFilter` and
`test_the_class_filter_members_match` goes red naming the extra member.
"""

from typing import Final, Literal, get_args

from app.presentation.activity_payload import Kind
from app.presentation.allocation_rows import GroupBy as ProjectionGroupBy
from app.presentation.positions_payload import AssetFilter
from app.schemas.view_options_tabs import ActivityKind, AssetClassFilter, GroupBy

#: Every pair this module asserts, so adding a third is one tuple, not a
#: fourth near-identical test.
PAIRS: Final[tuple[tuple[str, object, object], ...]] = (
    ("asset_class", AssetClassFilter, AssetFilter),
    ("kind", ActivityKind, Kind),
    ("group_by", GroupBy, ProjectionGroupBy),
)


def _members(alias: object) -> frozenset[str]:
    """The literal values of a `Literal[...]` alias."""
    return frozenset(str(value) for value in get_args(alias))


def test_every_pair_names_two_real_literals() -> None:
    """Anti-vacuity: a typo'd import would make every comparison trivially true."""
    for name, endpoint, projection in PAIRS:
        assert _members(endpoint), name
        assert _members(projection), name


def test_the_class_filter_members_match() -> None:
    """The endpoint must accept exactly what `holdings.positions.v1` declares."""
    assert _members(AssetClassFilter) == _members(AssetFilter)


def test_every_declared_pair_agrees_member_for_member() -> None:
    """The general form: a value on one side only is a 422 nobody expects."""
    disagreements = {
        name: sorted(_members(endpoint) ^ _members(projection))
        for name, endpoint, projection in PAIRS
        if _members(endpoint) != _members(projection)
    }

    assert not disagreements, (
        f"{disagreements} — the endpoint's enum and the projection's enum are "
        "two declarations of one closed set. A member on the projection's "
        "side alone is advertised by the catalog and answered 422 by the "
        "route; a member on the endpoint's side alone is accepted and then "
        "rejected one layer in."
    )


def test_the_comparison_would_notice_a_new_member() -> None:
    """The check itself, checked — it must not be an equality that cannot fail."""
    widened = Literal["all", "equities", "bonds", "alternatives", "cash", "crypto"]

    assert _members(widened) != _members(AssetFilter)
    assert _members(widened) - _members(AssetFilter) == {"crypto"}
