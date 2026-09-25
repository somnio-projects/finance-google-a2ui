"""``attribution.window.v1`` — the surface says what the sentence says.

The defect this view closes, measured on the deployed build on 2026-09-22:
the agent's ``compute_attribution`` tool computed a **window** and attached
``attribution.waterfall.v1``, which walks **unrealised P/L from cost basis**.
Asked *"what moved my portfolio today?"* the app answered "+$3,240.18 (0.68%)
today, driven by NVIDIA +$4,370.40" above a chart headed *Unrealised P/L
attribution · Net +$61,204.05 (+14.51%)* with NVIDIA at **+$34,019.40**. Asked
*"why did I move?"* it said NVIDIA was the biggest **loss** of the week
(-$7,871.40) above the same chart showing it as the biggest **gain**.

So the assertion that matters is not "the payload has fields". It is that the
figures on the surface are the ones the window produced — which is why
``the surface carries the window's own figures, not the all-time walk's``
compares the two projections directly and would fail if the tool's view were
pointed back at the waterfall.
"""

from datetime import UTC, datetime, timedelta
from decimal import Decimal

import pytest

from app.domain.attribution import attribute_window
from app.domain.portfolio import Portfolio
from app.domain.seed import seed_portfolio
from app.presentation.views import attribution_waterfall as all_time
from app.presentation.views import attribution_window as view
from app.presentation.window_payload import (
    WINDOW_DAYS,
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


class TestTheWindowIsWhatIsDrawn:
    """Every figure on the surface belongs to the window that was asked for."""

    @pytest.mark.parametrize("window", sorted(WINDOW_DAYS))
    def test_the_net_is_the_window_s_own_change(
        self, portfolio: Portfolio, window: str
    ) -> None:
        expected = attribute_window(
            portfolio, window=timedelta(days=WINDOW_DAYS[window])
        )
        payload = render(portfolio, window=window)

        assert payload.net.amount.amount == expected.change
        assert payload.start.amount.amount == expected.start_value
        assert payload.end.amount.amount == expected.end_value

    @pytest.mark.parametrize("window", sorted(WINDOW_DAYS))
    def test_the_title_and_the_period_name_the_window(
        self, portfolio: Portfolio, window: str
    ) -> None:
        payload = render(portfolio, window=window)

        assert payload.window == window
        assert payload.period == WINDOW_WORDS[window]
        assert payload.title.endswith(WINDOW_WORDS[window])

    def test_the_surface_carries_the_window_s_figures_not_the_all_time_walk_s(
        self, portfolio: Portfolio
    ) -> None:
        # The defect, as a test. `1d` and the all-time walk disagree about
        # every figure, and the surface must carry the first.
        today = render(portfolio, window="1d")
        walked = all_time.render(portfolio, all_time.AttributionWaterfallOptions())

        assert today.net.amount.amount != walked.net.amount.amount
        assert today.buckets[0].delta.amount != walked.buckets[0].delta.amount

    def test_the_steps_sum_to_the_headline(self, portfolio: Portfolio) -> None:
        # A waterfall whose bars do not reach its end bar is worse than no
        # chart; the domain guarantees it and this proves the projection did
        # not lose it on the way out.
        payload = render(portfolio, window="7d")
        total = sum((step.delta.amount for step in payload.buckets), start=Decimal(0))

        assert total == payload.net.amount.amount

    def test_the_last_step_s_running_total_is_where_the_walk_ends(
        self, portfolio: Portfolio
    ) -> None:
        payload = render(portfolio, window="7d")

        assert payload.buckets[-1].cumulative.amount == payload.end.amount.amount


class TestEveryFigureIsPreFormatted:
    """Nothing reaches the client as a number it has to format."""

    def test_each_step_shows_its_move_between_two_values(
        self, portfolio: Portfolio
    ) -> None:
        step = render(portfolio, window="1d").buckets[0]

        assert step.detail == (
            f"{step.move.display} · {step.opened.display} → {step.closed.display}"
        )
        assert step.delta_label == "Contribution"

    def test_a_negative_step_is_signed_and_pointed_down(
        self, portfolio: Portfolio
    ) -> None:
        payload = render(portfolio, window="7d")
        down = next(s for s in payload.buckets if s.delta.amount < 0)

        assert down.delta.display.startswith("-")
        assert down.direction == "down"

    def test_a_positive_step_is_signed_and_pointed_up(
        self, portfolio: Portfolio
    ) -> None:
        payload = render(portfolio, window="7d")
        up = next(s for s in payload.buckets if s.delta.amount >= 0)

        assert up.delta.display.startswith("+")
        assert up.direction == "up"

    def test_the_net_annotation_carries_the_period(self, portfolio: Portfolio) -> None:
        # The whole point: a figure with no window beside a sentence that has
        # one is what the reader could not reconcile.
        payload = render(portfolio, window="7d")

        assert payload.annotations[-1].text.endswith(WINDOW_WORDS["7d"])
