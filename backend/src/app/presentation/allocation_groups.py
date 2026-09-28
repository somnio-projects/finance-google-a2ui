"""The groupings the donut offers, as the toggle that switches them (GGU-145).

The design draws a segmented control above the card — *By asset class* ·
*By sector* — and `group_by` was already the declared option behind it. What
the payload lacked was the **choices**: their values, and a word for each.

**Why the words come from here and not from the client.** A client that wrote
"By asset class" beside a server enum would be authoring copy for a value the
server owns, and it would not follow the `locale` option (N-1, N-9) — the same
reason `direction_label` and every `*Display` string are server-written. It
would also silently narrow the enum: the design draws two segments and the
option declares three, and only the server can say whether the third is
missing on purpose.

So the payload names every declared choice, in the order the toggle shows
them, and marks the one this render used. The client draws one segment per
entry and sends the value back through the option it came from.
"""

from typing import Final

from pydantic import BaseModel, ConfigDict, Field

from app.presentation.allocation_rows import GroupBy

#: The word each grouping shows on its segment. Every value of ``GroupBy`` has
#: one, so a fourth grouping fails the type check here rather than reaching a
#: client with a blank segment.
GROUP_LABELS: Final[dict[GroupBy, str]] = {
    "holding": "By holding",
    "asset_class": "By asset class",
    "sector": "By sector",
}


class GroupChoice(BaseModel):
    """One segment of the grouping toggle."""

    model_config = ConfigDict(frozen=True)

    value: GroupBy = Field(
        description="The `group_by` option value this segment selects.",
        examples=["asset_class"],
    )
    label: str = Field(
        max_length=32,
        description="The word the segment shows, written here so it follows `locale`.",
        examples=["By asset class"],
    )
    selected: bool = Field(
        description="True on the one grouping this render used.", examples=[True]
    )


def choices(selected: GroupBy) -> tuple[GroupChoice, ...]:
    """Return every declared grouping, in toggle order, marking ``selected``.

    Args:
        selected: The grouping this render actually used.

    Returns:
        One entry per declared choice. The order is ``GROUP_LABELS``' own,
        which is the order the design draws — N-10 applies to the client, so
        the sequence has to be decided here.
    """
    return tuple(
        GroupChoice(value=value, label=label, selected=value == selected)
        for value, label in GROUP_LABELS.items()
    )


__all__ = ["GROUP_LABELS", "GroupChoice", "choices"]
