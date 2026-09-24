"""``attribution.window.v1`` — its declared options and its A2UI surface.

Split from ``test_attribution_window.py`` at the 150-line budget. That file
asserts the figures are the window's; this one asserts the contract around
them: the options are bounded and defaulted, and the surface publishes the
window it drew under the component name design already owns.
"""

from datetime import UTC, datetime

import pytest

from app.domain.portfolio import Portfolio
from app.domain.seed import seed_portfolio
from app.presentation.views import attribution_window as view
from app.presentation.window_payload import (
    VIEW_ID,
    WINDOW_WORDS,
    AttributionWindowPayload,
)

AS_OF = datetime(2026, 9, 22, tzinfo=UTC)


@pytest.fixture(name="portfolio")
def portfolio_fixture() -> Portfolio:
    """The curated portfolio, at a fixed instant so figures are stable."""
    return seed_portfolio(as_of=AS_OF)


def render(
    portfolio: Portfolio,
    *,
    window: str = view.DEFAULT_WINDOW,
    fields: tuple[str, ...] | None = None,
) -> AttributionWindowPayload:
    """Render the view the way the endpoint does, with its defaults."""
    options = (
        view.AttributionWindowOptions(window=window)
        if fields is None
        else view.AttributionWindowOptions(window=window, fields=fields)
    )
    return view.render(portfolio, options)


class TestTheDeclaredOptions:
    """Bounded, defaulted, and a 422 for anything else."""

    def test_the_default_window_is_today(self, portfolio: Portfolio) -> None:
        assert render(portfolio).window == view.DEFAULT_WINDOW

    def test_an_unknown_window_is_refused(self) -> None:
        with pytest.raises(ValueError, match="window"):
            view.AttributionWindowOptions(window="all")

    def test_field_selection_can_drop_each_section(self, portfolio: Portfolio) -> None:
        assert render(portfolio, fields=("annotations",)).buckets == ()
        assert render(portfolio, fields=("buckets",)).annotations == ()


class TestTheSurfaceAndTheRegistry:
    """What the client registers against, and what the catalog publishes."""

    def test_the_component_is_the_design_s_waterfall(
        self, portfolio: Portfolio
    ) -> None:
        # One component, two questions: the client reuses the painter.
        assert view.surface(render(portfolio)).component == "AttributionWaterfall"

    def test_the_surface_publishes_the_window_it_drew(
        self, portfolio: Portfolio
    ) -> None:
        drawn = view.surface(render(portfolio, window="30d"))

        assert drawn.props["window"] == "30d"
        assert drawn.props["period"] == WINDOW_WORDS["30d"]
        assert drawn.view == VIEW_ID

    def test_the_selection_rule_never_volunteers_it(self, portfolio: Portfolio) -> None:
        # A window is asked for by id; the all-time walk stays the default
        # explanation, so this must not compete with it.
        assert view.fitness(portfolio) == view.NEVER_SELECTED
