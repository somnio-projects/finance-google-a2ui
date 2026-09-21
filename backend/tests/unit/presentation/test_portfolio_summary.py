"""Spec 0026 — ``portfolio.summary.v1`` is the Home hero, served whole."""

from datetime import UTC, datetime

import pytest
from pydantic import ValidationError

from app.domain.persona import DEMO_ACCOUNT
from app.domain.portfolio import Portfolio
from app.presentation.registry import REGISTRY
from app.presentation.summary_options import PortfolioSummaryOptions
from app.presentation.summary_questions import SUGGESTED_QUESTIONS
from app.presentation.views.portfolio_summary import VIEW_ID, fitness, render, surface


def test_render_is_the_home_page_header_and_hero(portfolio: Portfolio) -> None:
    payload = render(portfolio, PortfolioSummaryOptions())
    assert payload.view == VIEW_ID
    assert payload.greeting == "Good afternoon"  # FROZEN_NOW is noon
    assert (payload.account.name, payload.account.initial) == ("Alex Chen", "A")
    assert payload.badge == "Simulated portfolio"
    assert payload.total.label == "Total portfolio value"
    assert payload.total.amount.display == "$482,915.20"
    assert payload.change.amount.display == "+$3,240.18"
    assert payload.questions_title == "Suggested questions"
    assert payload.movers_title == "Top movers today"
    assert len(payload.spark) == 30


def test_the_persona_is_seed_data_not_the_token_subject(portfolio: Portfolio) -> None:
    payload = render(portfolio, PortfolioSummaryOptions())
    assert payload.account.name == DEMO_ACCOUNT.name != "alice"


def test_the_questions_are_the_three_chips_the_design_draws(
    portfolio: Portfolio,
) -> None:
    payload = render(portfolio, PortfolioSummaryOptions())
    assert payload.questions == SUGGESTED_QUESTIONS
    assert [q.text for q in payload.questions] == [
        "What moved my portfolio today?",
        "Tax impact of selling NVDA?",
        "Build a $10k order in tech",
    ]


def test_render_is_pure_over_the_same_inputs(portfolio: Portfolio) -> None:
    assert render(portfolio, PortfolioSummaryOptions()) == render(
        portfolio, PortfolioSummaryOptions()
    )


def test_render_honours_the_display_options(portfolio: Portfolio) -> None:
    payload = render(portfolio, PortfolioSummaryOptions(precision=0, locale="de-DE"))
    assert payload.total.amount.display == "482.915 $"
    assert payload.spark[-1].label == "18.09.2026"


def test_surface_names_the_component_and_carries_every_block(
    portfolio: Portfolio,
) -> None:
    payload = render(portfolio, PortfolioSummaryOptions())
    drawn = surface(payload)
    assert drawn.component == "PortfolioSummary"
    assert drawn.view == VIEW_ID
    assert drawn.title == "Total portfolio value"
    assert set(drawn.props) == {
        "greeting",
        "account",
        "badge",
        "total",
        "change",
        "spark",
        "questions",
        "movers",
    }
    assert drawn.props["change"]["trend"] == "up"
    assert len(drawn.props["movers"]) == 3


def test_fitness_needs_a_portfolio_to_summarise(portfolio: Portfolio) -> None:
    assert fitness(portfolio) == 1
    empty = Portfolio(
        as_of=datetime(2026, 9, 18, tzinfo=UTC), positions=(), lots=(), ledger=()
    )
    assert fitness(empty) == 0


def test_only_declared_ranges_are_accepted() -> None:
    with pytest.raises(ValidationError):
        PortfolioSummaryOptions(range="2y")  # pyright: ignore[reportArgumentType]
    with pytest.raises(ValidationError):
        PortfolioSummaryOptions(nonsense=1)  # pyright: ignore[reportCallIssue]


def test_the_view_is_registered_under_its_id() -> None:
    assert VIEW_ID in {projection.id for projection in REGISTRY.all()}
