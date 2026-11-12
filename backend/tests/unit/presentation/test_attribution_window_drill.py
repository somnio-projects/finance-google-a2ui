"""Spec 0056 AC-1, OD-2 — today's walk offers the drill; a week's does not.

GGU-161 was this declaration's absence: Flow A's turn draws the window view,
the client reads the drill's ``choices`` from the payload, found none and kept
the tap to itself. Asserted on the payload **and** the A2UI props, because the
two clients read different halves.
"""

from datetime import UTC, datetime

import pytest

from app.actions.declared import declared_action
from app.actions.defined.drill_attribution import ACTION as DRILL
from app.domain.seed import seed_portfolio
from app.presentation.views import attribution_window as view
from app.presentation.window_payload import DRILL_WINDOW, window_actions

AS_OF = datetime(2026, 9, 22, tzinfo=UTC)


def _render(window: str) -> view.AttributionWindowPayload:
    options = view.AttributionWindowOptions(window=window)
    return view.render(seed_portfolio(as_of=AS_OF), options)


def test_today_window_declares_the_drill_in_payload_and_props() -> None:
    payload = _render(DRILL_WINDOW)

    assert payload.actions == (declared_action(DRILL),)
    props = view.surface(payload).props
    assert props["actions"] == [declared_action(DRILL).model_dump(mode="json")]


def test_today_window_drill_accepts_every_bucket_it_draws() -> None:
    """A bar the reader can select but not drill would be a dead affordance."""
    payload = _render(DRILL_WINDOW)

    keys = {step.key for step in payload.buckets}
    assert keys <= set(payload.actions[0].choices)


@pytest.mark.parametrize("window", ["7d", "30d"], ids=["week", "month"])
def test_longer_windows_declare_no_drill(window: str) -> None:
    """OD-2 — the driver card is a day view; it cannot answer a week."""
    payload = _render(window)

    assert payload.actions == ()
    assert view.surface(payload).props["actions"] == []
    assert window_actions(window) == ()
