"""AC-6, AC-7, AC-8, AC-10 — the service both callers share (spec 0005).

The service is where a view id and a set of options become a payload, so the
rejections live here too: everything the controller and the agent path can be
told "no" about is asserted against the service, once.
"""

import uuid

import pytest

from app.core.errors import NotFoundError
from app.core.principal import Principal
from app.domain.provider import InMemoryPortfolioProvider
from app.helpers.clock import FixedClock
from app.presentation.errors import UnknownViewError
from app.presentation.registry import REGISTRY
from app.schemas.views import CURRENT_PORTFOLIO, ViewQuery
from app.services.view_service import ViewService
from tests.catalog import SHIPPED_VIEWS
from tests.conftest import FROZEN_NOW

ALLOCATION = "holdings.allocation.v1"
WATERFALL = "attribution.waterfall.v1"
TAX_LOTS = "taxlots.table.v1"
SCENARIO = "scenario.comparison.v1"


@pytest.fixture
def service() -> ViewService:
    provider = InMemoryPortfolioProvider(clock=FixedClock(FROZEN_NOW))
    return ViewService(provider=provider, registry=REGISTRY)


async def test_render_answers_one_keyed_entry_per_requested_view(
    service: ViewService, principal: Principal
) -> None:
    response = await service.render(
        principal,
        portfolio_id=CURRENT_PORTFOLIO,
        query=ViewQuery(view=[ALLOCATION, WATERFALL]),
        default=ALLOCATION,
    )
    assert list(response.views) == [ALLOCATION, WATERFALL]
    assert response.views[ALLOCATION].model_dump()["view"] == ALLOCATION
    assert response.views[WATERFALL].model_dump()["view"] == WATERFALL
    assert response.as_of == FROZEN_NOW
    assert response.portfolio_id == CURRENT_PORTFOLIO


async def test_render_applies_the_shared_options_to_every_view(
    service: ViewService, principal: Principal
) -> None:
    response = await service.render(
        principal,
        portfolio_id=CURRENT_PORTFOLIO,
        query=ViewQuery(view=[ALLOCATION, WATERFALL], precision=0),
        default=ALLOCATION,
    )
    dumped = response.views[ALLOCATION].model_dump()
    assert dumped["total"]["amount"]["display"] == "$482,915"


async def test_render_uses_the_selection_rule_when_no_view_is_named(
    service: ViewService, principal: Principal
) -> None:
    response = await service.render(
        principal,
        portfolio_id=CURRENT_PORTFOLIO,
        query=ViewQuery(),
        default=ALLOCATION,
    )
    assert list(response.views) == [WATERFALL]  # the seed has winners and losers


async def test_render_rejects_an_option_the_view_does_not_declare(
    service: ViewService, principal: Principal
) -> None:
    with pytest.raises(Exception, match=r"rejected option\(s\) \['top_n'\]"):
        await service.render(
            principal,
            portfolio_id=CURRENT_PORTFOLIO,
            query=ViewQuery(view=[WATERFALL], top_n=3),
            default=ALLOCATION,
        )


async def test_render_rejects_an_unknown_view(
    service: ViewService, principal: Principal
) -> None:
    with pytest.raises(UnknownViewError, match="is not registered"):
        await service.render(
            principal,
            portfolio_id=CURRENT_PORTFOLIO,
            query=ViewQuery(view=["nope.thing.v1"]),
            default=ALLOCATION,
        )


async def test_only_the_current_portfolio_is_addressable(
    service: ViewService, principal: Principal
) -> None:
    assert (await service.portfolio(principal)).as_of == FROZEN_NOW
    with pytest.raises(NotFoundError, match="does not exist"):
        await service.portfolio(principal, portfolio_id="someone-else")


async def test_two_subjects_get_independent_portfolios(service: ViewService) -> None:
    def make(subject: str) -> Principal:
        return Principal(
            subject=subject, provider="fake", token_fingerprint="0123456789abcdef"
        )

    first = await service.portfolio(make(f"user-{uuid.uuid4()}"))
    second = await service.portfolio(make(f"user-{uuid.uuid4()}"))
    assert first is not second


async def test_catalog_describes_every_registered_projection(
    service: ViewService,
) -> None:
    catalog = await service.catalog()
    assert tuple([entry.id for entry in catalog]) == SHIPPED_VIEWS
    assert {WATERFALL, ALLOCATION} <= {entry.id for entry in catalog}
    for entry, projection in zip(catalog, REGISTRY.all(), strict=True):
        assert entry.summary == projection.summary
        assert entry.endpoints == list(projection.endpoints)
        assert entry.options_schema["properties"]
        assert projection.dto.model_validate(entry.example)


async def test_surface_goes_through_the_view_own_adapter(
    service: ViewService, principal: Principal
) -> None:
    portfolio = await service.portfolio(principal)
    payload = service.render_one(portfolio, view=ALLOCATION, options={})
    assert service.surface(ALLOCATION, payload).component == "HoldingsSummary"
