"""Spec 0012 AC-5 — one failing entry must not sink the batch.

The service's whole reason to exist is the error path, so that is what is
asserted here: every failure mode a projection can produce becomes *this
entry's* problem document, with the rest of the batch still rendered.
"""

import uuid

import pytest

from app.core.principal import Principal
from app.domain.provider import InMemoryPortfolioProvider
from app.helpers.clock import FixedClock
from app.presentation.registry import REGISTRY
from app.presentation.views import LOADED
from app.schemas.view_renders import ViewRenderBatch
from app.services.view_render_service import ViewRenderService
from app.services.view_service import ViewService
from tests.conftest import FROZEN_NOW

ALLOCATION = "holdings.allocation.v1"
WATERFALL = "attribution.waterfall.v1"


@pytest.fixture
def service() -> ViewRenderService:
    assert LOADED, "importing the views package is what fills the registry"
    views = ViewService(
        provider=InMemoryPortfolioProvider(clock=FixedClock(FROZEN_NOW)),
        registry=REGISTRY,
    )
    return ViewRenderService(views=views)


@pytest.fixture
def caller() -> Principal:
    return Principal(
        subject=f"user-{uuid.uuid4()}",
        provider="fake",
        email=None,
        scopes=frozenset({"read"}),
        token_fingerprint="0123456789abcdef",  # gitleaks:allow - test fixture
    )


async def test_every_entry_is_rendered_in_request_order(
    service: ViewRenderService, caller: Principal
) -> None:
    batch = ViewRenderBatch.model_validate(
        {"renders": [{"view": WATERFALL}, {"view": ALLOCATION}]}
    )

    answer = await service.render_batch(caller, batch=batch)

    assert [result.view for result in answer.results] == [WATERFALL, ALLOCATION]
    assert all(result.status == 200 for result in answer.results)
    assert all(result.as_of == FROZEN_NOW for result in answer.results)
    assert answer.results[0].payload is not None
    assert answer.results[0].error is None


async def test_an_unknown_view_fails_only_its_own_entry(
    service: ViewRenderService, caller: Principal
) -> None:
    batch = ViewRenderBatch.model_validate(
        {"renders": [{"view": "nope.thing.v1"}, {"view": ALLOCATION}]}
    )

    answer = await service.render_batch(caller, batch=batch)

    failed, rendered = answer.results
    assert failed.status == 404
    assert failed.payload is None
    assert failed.as_of is None
    assert failed.error is not None
    assert failed.error.type.endswith("/portfolio/unknown-view")
    assert rendered.status == 200
    assert rendered.payload is not None


async def test_an_undeclared_option_is_a_422_on_that_entry_alone(
    service: ViewRenderService, caller: Principal
) -> None:
    batch = ViewRenderBatch.model_validate(
        {
            "renders": [
                {"view": WATERFALL, "options": {"top_n": 3}},
                {"view": WATERFALL},
            ]
        }
    )

    answer = await service.render_batch(caller, batch=batch)

    assert [result.status for result in answer.results] == [422, 200]
    assert answer.results[0].error is not None
    assert answer.results[0].error.status == 422


async def test_another_subjects_portfolio_is_a_404_on_that_entry(
    service: ViewRenderService, caller: Principal
) -> None:
    """A caller must not reach another portfolio by naming it in a batch."""
    batch = ViewRenderBatch.model_validate(
        {"renders": [{"view": ALLOCATION, "portfolio_id": "someone-else"}]}
    )

    answer = await service.render_batch(caller, batch=batch)

    assert answer.results[0].status == 404
    assert answer.results[0].error is not None
    assert answer.results[0].error.type.endswith("/not-found")


async def test_an_entry_problem_carries_no_request_context(
    service: ViewRenderService, caller: Principal
) -> None:
    """`instance` and `request_id` belong to the batch, not to an entry."""
    batch = ViewRenderBatch.model_validate({"renders": [{"view": "nope.thing.v1"}]})

    answer = await service.render_batch(caller, batch=batch)
    problem = answer.results[0].error

    assert problem is not None
    assert problem.instance is None
    assert problem.request_id is None
