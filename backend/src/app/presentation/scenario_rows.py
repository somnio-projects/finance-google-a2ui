"""The comparison as the frame draws it: one row per metric (spec 0051).

The card was column-major — a reader scanned a method and read its figures
down. The redesign is **row-major**: a reader scans *Est. tax* across and sees
which column wins it, with a tick and a tinted cell.

So a row carries what a row needs and **no figures**: the numbers are already
in ``columns[]`` under the same names, and a payload that shipped each twice
would be two places for one fact. The client pairs ``rows[].key`` with the
column field of that name — a literal path in the component, which is what
N-5 asks for.

``winner`` is the whole reason this exists. Marking the best cell means
comparing two numbers, and the client may not (N-2). It is decided here, and
tested as a **relationship** — for every render, the named column's figure is
the best in its row under that row's direction — rather than as a literal per
row, because every figure can be right while the tick sits on the wrong one.
"""

from typing import Final, Literal

from pydantic import BaseModel, ConfigDict, Field

#: The metrics the frame lays out, in the order it draws them.
RowKey = Literal["proceeds", "realized_pl", "est_tax", "net_after_tax"]

#: Which way is better, per row. Server-written so it follows `locale`; a Dart
#: constant beside the row label would not (N-9).
HIGHER: Final[str] = "higher is better"
LOWER: Final[str] = "lower is better"

#: The rows, with their captions and which direction wins them. A tuple, so
#: the order the frame draws is the order the payload arrives in (N-10).
ROWS: Final[tuple[tuple[RowKey, str, str], ...]] = (
    ("proceeds", "Proceeds", HIGHER),
    ("realized_pl", "Realized gain", LOWER),
    ("est_tax", "Est. tax", LOWER),
    ("net_after_tax", "Net after tax", HIGHER),
)


class ScenarioRow(BaseModel):
    """One metric across every column, and which column wins it."""

    model_config = ConfigDict(frozen=True)

    key: RowKey = Field(
        description="The column field this row reads.", examples=["est_tax"]
    )
    label: str = Field(
        max_length=48, description="The row's caption.", examples=["Est. tax"]
    )
    direction_label: str = Field(
        max_length=32,
        description="Which way is better, in words the client shows.",
        examples=[LOWER],
    )
    winner: str | None = Field(
        default=None,
        max_length=32,
        description=(
            "`columns[].key` of the best cell in this row, or null when every "
            "column ties. A server decision — N-2 forbids the client "
            "comparing two figures."
        ),
        examples=["hifo"],
    )


class ScenarioSummary(BaseModel):
    """The footer sentence, composed here so no client assembles one."""

    model_config = ConfigDict(frozen=True)

    text: str = Field(
        max_length=240,
        description="The whole sentence, with its figures already in it (N-9).",
        examples=["HIFO saves $2,240.00 in tax and keeps $2,240.00 more after tax."],
    )
    badge: str = Field(
        max_length=32,
        description="The pill in the header; server-written.",
        examples=["Best result"],
    )


__all__ = ["HIGHER", "LOWER", "ROWS", "RowKey", "ScenarioRow", "ScenarioSummary"]
