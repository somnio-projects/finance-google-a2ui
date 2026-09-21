"""AC-4, AC-8 — the Markdown the contract is made of.

Two things matter here beyond shape. A cell must not be able to break the table
it sits in, because a projection's `description` is free prose written by
whoever adds the chart. And a projection with no options has to *say* so: a
blank Options section reads as "not documented yet", which is the opposite of
what a frozen contract claims.
"""

from typing import Any

from app.presentation.catalog_tables import (
    NO_OPTIONS,
    READ_ONLY,
    cell,
    inputs_note,
    interactive_fields,
    inventory_table,
    option_inputs,
    options_table,
    table,
)
from app.presentation.inventory import InventoryField, inventory
from app.presentation.options import TopNOptions
from app.presentation.registry import REGISTRY


def _field(*, path: str, interaction: str) -> InventoryField:
    """Build one inventory row with only the columns this test reads."""
    return InventoryField(
        path=path,
        kind="string",
        presence="required",
        binding="text",
        state="—",
        interaction=interaction,
    )


def test_a_cell_cannot_break_the_table_it_sits_in() -> None:
    assert cell("a | b") == "a \\| b"
    assert cell("first\nsecond") == "first second"
    assert cell("  padded  ") == "padded"


def test_table_renders_a_header_a_rule_and_one_line_per_row() -> None:
    rendered = table(("A", "B"), [("1", "2"), ("3", "4")])

    assert rendered.splitlines() == [
        "| A | B |",
        "|---|---|",
        "| 1 | 2 |",
        "| 3 | 4 |",
    ]


def test_a_projection_without_options_says_so_instead_of_showing_an_empty_table() -> (
    None
):
    empty: dict[str, Any] = {"type": "object"}

    assert options_table(empty) == NO_OPTIONS
    assert option_inputs(empty) == {}


def test_the_options_table_prints_the_bound_the_model_is_also_taught() -> None:
    rendered = options_table(TopNOptions.model_json_schema())

    assert "| Option | Type / format | Accepts | Default | Description |" in rendered
    assert "| `top_n` | integer 1..20 | integer 1..20 | `5` |" in rendered
    assert "| `include_other` | boolean | true or false | `true` |" in rendered


def test_option_inputs_turns_every_declared_option_into_an_input_cell() -> None:
    assert option_inputs(TopNOptions.model_json_schema()) == {
        "top_n": "input · integer 1..20",
        "include_other": "input · true or false",
    }


def test_the_inventory_table_prints_one_row_per_field() -> None:
    projection = REGISTRY.get("holdings.allocation.v1")
    fields = inventory(projection.dto.model_json_schema(), inputs={})

    rendered = inventory_table(fields).splitlines()

    assert len(rendered) == len(fields) + 2
    assert rendered[0].startswith("| Field |")


def test_interactive_fields_names_only_the_rows_a_caller_can_send_back() -> None:
    rows = (
        _field(path="quantity", interaction="input · integer 1..20"),
        _field(path="title", interaction="—"),
    )

    assert interactive_fields(rows) == ("quantity",)
    assert inputs_note(rows) == "`quantity`"


def test_a_projection_with_no_editable_field_is_called_read_only() -> None:
    rows = (_field(path="title", interaction="—"),)

    assert interactive_fields(rows) == ()
    assert inputs_note(rows) == READ_ONLY
