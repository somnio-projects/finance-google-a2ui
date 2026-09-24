"""The view service names the caller for the greeting (spec 0030 OD-3)."""

from app.core.principal import Principal
from app.domain.persona import PortfolioOwner
from app.domain.provider import InMemoryPortfolioProvider
from app.helpers.clock import FixedClock
from app.presentation.registry import REGISTRY
from app.schemas.views import CURRENT_PORTFOLIO, ViewQuery
from app.services.view_service import ViewService
from tests.conftest import FROZEN_NOW

ALLOCATION = "holdings.allocation.v1"


class _NamesEveryone:
    async def owner_for(self, principal: Principal) -> PortfolioOwner | None:
        return PortfolioOwner(name=f"Owner of {principal.subject}", initial="O")


class _NamesNobody:
    async def owner_for(self, principal: Principal) -> PortfolioOwner | None:
        return None


async def test_the_portfolio_carries_the_owner_the_resolver_names(
    principal: Principal,
) -> None:
    """Spec 0030 OD-3 — the service sets the owner; projections read it."""
    provider = InMemoryPortfolioProvider(clock=FixedClock(FROZEN_NOW))
    service = ViewService(provider=provider, registry=REGISTRY, owners=_NamesEveryone())

    portfolio = await service.portfolio(principal)
    response = await service.render(
        principal,
        portfolio_id=CURRENT_PORTFOLIO,
        query=ViewQuery(view=["portfolio.summary.v1"]),
        default=ALLOCATION,
    )

    assert portfolio.owner == PortfolioOwner(
        name=f"Owner of {principal.subject}", initial="O"
    )
    account = response.views["portfolio.summary.v1"].model_dump()["account"]
    assert account == {"name": f"Owner of {principal.subject}", "initial": "O"}


async def test_without_a_name_the_portfolio_is_the_provider_s(
    principal: Principal,
) -> None:
    provider = InMemoryPortfolioProvider(clock=FixedClock(FROZEN_NOW))
    named = ViewService(provider=provider, registry=REGISTRY, owners=_NamesNobody())
    unnamed = ViewService(provider=provider, registry=REGISTRY)

    assert (await named.portfolio(principal)).owner is None
    assert (await unnamed.portfolio(principal)).owner is None
