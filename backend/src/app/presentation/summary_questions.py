"""The suggested questions the Home page offers (spec 0026 OD-6).

Three chips, transcribed from `Home.dc.html` and served as words rather than
built on the client, for the same reason every label is: N-9. Each one is a
question the agent's tools can actually answer — attribution (Flow A), the tax
impact of a sale (Flow B) and a draft order (Flow C) — so a tap never leads
to a capability the demo does not have.
"""

from typing import Final

from app.presentation.summary_payload import Question

QUESTIONS_TITLE: Final[str] = "Suggested questions"
MOVERS_TITLE: Final[str] = "Top movers today"

SUGGESTED_QUESTIONS: Final[tuple[Question, ...]] = (
    Question(text="What moved my portfolio today?"),
    Question(text="Tax impact of selling BTC?"),
    Question(text="Build a $10k order in tech"),
)

__all__ = ["MOVERS_TITLE", "QUESTIONS_TITLE", "SUGGESTED_QUESTIONS"]
