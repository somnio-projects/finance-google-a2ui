"""AC-1 — the registry, the Protocol and the option resolution (ADR-K D-7).

``ProjectionSpec`` is checked against the ``Projection`` Protocol here rather
than trusted: the Protocol is what four consumers read, so a spec that drifts
out of shape must fail a test, not a request.
"""

import pytest

from app.core.errors import ConfigurationError, ValidationFailedError
from app.domain.portfolio import Portfolio
from app.presentation.errors import UnknownViewError
from app.presentation.options import PrecisionOptions
from app.presentation.registry import REGISTRY, Projection, ProjectionRegistry
from app.presentation.resolve import validated_options
from app.presentation.spec import ProjectionSpec
from app.presentation.views.holdings_allocation import (
    VIEW_ID,
    HoldingsAllocationOptions,
    HoldingsAllocationPayload,
    render,
    surface,
)


def make_spec(view_id: str = "test.thing.v1") -> ProjectionSpec:
    """Build a throwaway spec around the allocation projection's callables."""
    return ProjectionSpec(
        id=view_id,
        summary="A throwaway projection defined by a test.",
        endpoints=("GET /v1/portfolios/{portfolio_id}/views",),
        options=HoldingsAllocationOptions,
        dto=HoldingsAllocationPayload,
        render=render,
        surface=surface,
        fitness=lambda _: 0,
    )


def test_projection_spec_satisfies_the_protocol() -> None:
    spec: Projection = make_spec()
    assert spec.id == "test.thing.v1"
    assert spec.options is HoldingsAllocationOptions
    assert spec.dto is HoldingsAllocationPayload


def test_spec_example_is_rendered_from_the_sample_portfolio(
    portfolio: Portfolio,
) -> None:
    example = make_spec().example
    assert example["view"] == VIEW_ID
    assert HoldingsAllocationPayload.model_validate(example)
    assert portfolio.holdings()  # the seed the example mirrors is not empty


def test_register_publishes_the_projection(registry: ProjectionRegistry) -> None:
    spec = make_spec()
    registry.add(spec)
    assert registry.get("test.thing.v1") is spec
    assert [p.id for p in registry.all()] == ["test.thing.v1"]


def test_registry_orders_projections_by_id(registry: ProjectionRegistry) -> None:
    registry.add(make_spec("zzz.thing.v1"))
    registry.add(make_spec("aaa.thing.v1"))
    assert [p.id for p in registry.all()] == ["aaa.thing.v1", "zzz.thing.v1"]


def test_register_rejects_a_duplicate_id(registry: ProjectionRegistry) -> None:
    registry.add(make_spec())
    with pytest.raises(ConfigurationError, match="already registered"):
        registry.add(make_spec())


def test_registry_get_rejects_an_unknown_id(registry: ProjectionRegistry) -> None:
    with pytest.raises(UnknownViewError, match=r"'nope\.v1' is not registered"):
        registry.get("nope.v1")
    assert UnknownViewError().code == "portfolio/unknown-view"


def test_registry_remove_is_idempotent(registry: ProjectionRegistry) -> None:
    registry.add(make_spec())
    registry.remove("test.thing.v1")
    registry.remove("test.thing.v1")
    assert registry.all() == ()


def test_the_process_registry_holds_both_reference_projections() -> None:
    assert [p.id for p in REGISTRY.all()] == [
        "attribution.waterfall.v1",
        "holdings.allocation.v1",
    ]


def test_validated_options_fills_the_declared_defaults() -> None:
    options = validated_options(make_spec(), {"top_n": 2})
    assert isinstance(options, HoldingsAllocationOptions)
    assert (options.top_n, options.precision, options.sort) == (2, 2, "value_desc")


@pytest.mark.parametrize(
    ("supplied", "named"),
    [({"nope": 1}, "nope"), ({"precision": 99}, "precision")],
    ids=["undeclared-option", "out-of-range-option"],
)
def test_validated_options_names_the_offending_option(
    supplied: dict[str, object], named: str
) -> None:
    with pytest.raises(ValidationFailedError, match=named) as raised:
        validated_options(make_spec(), supplied)
    # the message names the option, never the value the caller sent
    assert "99" not in raised.value.detail


def test_validated_options_accepts_a_model_with_no_knobs_at_all() -> None:
    spec = ProjectionSpec(
        id="bare.thing.v1",
        summary="No options at all.",
        endpoints=(),
        options=PrecisionOptions,
        dto=HoldingsAllocationPayload,
        render=render,
        surface=surface,
        fitness=lambda _: 0,
    )
    assert validated_options(spec, {}) == PrecisionOptions()
