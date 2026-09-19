"""AC-9 — the model picks, it does not invent (ADR-K D-11, D-12).

The two rejection cases are the point of this file: a model that asks for a
view that does not exist, and one that fills an option the view never
declared. Both must be recorded and both must still produce a surface, or an
agent turn ends on an error instead of a chart.
"""

import re

import pytest

from app.core.principal import Principal
from app.domain.provider import InMemoryPortfolioProvider
from app.helpers.clock import FixedClock
from app.presentation.registry import REGISTRY
from app.schemas.render_intent import RenderIntent
from app.services.render_intent_service import REJECTED_METRIC, RenderIntentService
from app.services.view_service import ViewService
from tests.conftest import FROZEN_NOW, FakeReporter

ALLOCATION = "holdings.allocation.v1"
WATERFALL = "attribution.waterfall.v1"


@pytest.fixture
def intents(reporter: FakeReporter) -> RenderIntentService:
    provider = InMemoryPortfolioProvider(clock=FixedClock(FROZEN_NOW))
    views = ViewService(provider=provider, registry=REGISTRY)
    return RenderIntentService(views=views, reporter=reporter)


async def test_accepted_intent_renders_the_requested_view(
    intents: RenderIntentService, principal: Principal, reporter: FakeReporter
) -> None:
    result = await intents.render(
        principal, RenderIntent(view=WATERFALL, options={"precision": 0})
    )
    assert result.view == WATERFALL
    assert result.rejection is None
    assert result.surface.component == "WaterfallChart"
    assert result.payload.model_dump()["start"]["amount"]["display"] == "$56,925"
    assert reporter.metrics == []


@pytest.mark.parametrize(
    ("intent", "reason"),
    [
        (RenderIntent(view="nope.thing.v1"), "is not registered"),
        (
            RenderIntent(view=WATERFALL, options={"top_n": 3}),
            r"rejected option\(s\) \['top_n'\]",
        ),
    ],
    ids=["unknown-view", "undeclared-option"],
)
async def test_a_rejected_intent_falls_back_and_is_reported(
    intents: RenderIntentService,
    principal: Principal,
    reporter: FakeReporter,
    intent: RenderIntent,
    reason: str,
) -> None:
    result = await intents.render(principal, intent, default=ALLOCATION)
    assert result.view == ALLOCATION
    assert result.rejection is not None
    assert re.search(reason, result.rejection), result.rejection
    assert result.surface.component == "DonutChart"
    assert reporter.metrics == [(REJECTED_METRIC, {"view": intent.view})]


async def test_the_fallback_still_renders_a_bindable_payload(
    intents: RenderIntentService, principal: Principal
) -> None:
    result = await intents.render(
        principal, RenderIntent(view="nope.thing.v1"), default=ALLOCATION
    )
    dumped = result.payload.model_dump()
    assert dumped["view"] == ALLOCATION
    assert dumped["categories"]
