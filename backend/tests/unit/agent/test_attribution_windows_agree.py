"""The tool's windows and the surface's windows are the same closed set.

`compute_attribution` declares which windows the model may ask for, and
``attribution.window.v1`` declares which windows it will draw. They must be
the same set: a window the model can send but the surface cannot render is a
422 the model cannot see coming, and a window the surface accepts but the
model cannot ask for is a control nobody can reach.

They are **two literals on purpose**. `app.agent` is an inner layer that may
import nothing outside `app.core` and `app.domain` (spec 0006 AC-2), so the
tool cannot read the projection's declaration. This file is the other half of
that trade: the rule in `.claude/rules/backend/testing.md` is that a property
spanning two declarations gets a test comparing them.
"""

from app.agent.tools.attribution import DEFAULT_WINDOW as TOOL_DEFAULT
from app.agent.tools.attribution import WINDOWS as TOOL_WINDOWS
from app.presentation.window_payload import WINDOW_DAYS, WINDOW_WORDS


def test_the_tool_and_the_surface_accept_the_same_windows() -> None:
    assert dict(TOOL_WINDOWS) == dict(WINDOW_DAYS)


def test_every_window_the_tool_offers_has_words_the_surface_can_title() -> None:
    # A window with no phrase would make the client compose one out of a
    # code, which is the client formatting — the thing this product forbids.
    assert sorted(WINDOW_WORDS) == sorted(TOOL_WINDOWS)


def test_the_tool_s_default_is_one_the_surface_draws() -> None:
    assert TOOL_DEFAULT in WINDOW_DAYS
