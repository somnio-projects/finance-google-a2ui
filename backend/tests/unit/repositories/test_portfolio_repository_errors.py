"""What the portfolio repository does when the database refuses (spec 0020).

Error paths, and only error paths. The happy path needs a real PostgreSQL and
lives in `tests/integration/`; these are the branches a working database never
takes, which is exactly why they would otherwise ship unexercised.

The rule they enforce: **a driver exception never escapes the repository.**
Services and the domain import no SQLAlchemy, so a bare `SQLAlchemyError`
reaching them would be an error nobody upstream can name — it leaves as
`DependencyUnavailableError`, which the API turns into a 503 problem document
with no internals.

`IntegrityError` is the one exception that passes through on purpose: it is not
a failure, it is the answer to "who won the race", and the provider handles it.
"""

import pytest
from sqlalchemy.exc import IntegrityError, OperationalError

from app.core.errors import DependencyUnavailableError
from app.domain.seed import seed_portfolio
from app.repositories.portfolio_repository import PortfolioRepository
from tests.conftest import FROZEN_NOW

SUBJECT = "subject-error"


class BrokenSession:
    """A session whose every statement fails the way a lost database does."""

    def __init__(self, error: Exception) -> None:
        """Raise ``error`` from `execute`; record whether a flush happened."""
        self._error = error
        self.flushed = False

    async def execute(self, *_: object, **_kwargs: object) -> object:
        """Fail the way a dropped connection does."""
        raise self._error

    def add(self, *_: object) -> None:
        """Accept the entity; the failure comes from the statement."""

    def add_all(self, *_: object) -> None:
        """Accept the entities; the failure comes from the statement."""

    async def flush(self) -> None:
        """Record the flush so a test can tell how far a write got."""
        self.flushed = True

    def begin_nested(self) -> object:
        """Return a savepoint context that does nothing."""

        class _Savepoint:
            async def __aenter__(self) -> None:
                return None

            async def __aexit__(self, *_: object) -> bool:
                return False

        return _Savepoint()


def _repository(error: Exception) -> PortfolioRepository:
    """Build a repository over a session that always fails with ``error``."""
    return PortfolioRepository(BrokenSession(error))  # pyright: ignore[reportArgumentType]


def _driver_error() -> OperationalError:
    """Return the exception a dropped PostgreSQL connection produces."""
    return OperationalError("SELECT 1", (), Exception("connection closed"))


async def test_a_read_failure_becomes_a_named_dependency_error() -> None:
    with pytest.raises(DependencyUnavailableError, match="database read failed"):
        await _repository(_driver_error()).find(subject=SUBJECT)


async def test_a_read_failure_is_chained_not_swallowed() -> None:
    """The driver exception stays reachable as `__cause__` for the reporter."""
    original = _driver_error()

    with pytest.raises(DependencyUnavailableError) as caught:
        await _repository(original).find(subject=SUBJECT)

    assert caught.value.__cause__ is original


async def test_an_os_error_while_reading_is_handled_like_a_driver_error() -> None:
    """A socket that dies mid-statement is not a `SQLAlchemyError`."""
    with pytest.raises(DependencyUnavailableError, match="database read failed"):
        await _repository(OSError("connection reset")).find(subject=SUBJECT)


async def test_a_write_failure_becomes_a_named_dependency_error() -> None:
    with pytest.raises(DependencyUnavailableError, match="database read failed"):
        await _repository(_driver_error()).replace(
            subject=SUBJECT, portfolio=seed_portfolio(as_of=FROZEN_NOW)
        )


class ConflictingSession(BrokenSession):
    """Reads fine, then loses the race on the insert.

    Modelled on what actually happens: `replace` looks the subject up first
    and finds nothing, and only the INSERT collides. An earlier version of
    this test raised from `execute`, so the conflict was caught by the *read*
    handler and translated — the test passed for the wrong reason until it
    did not.
    """

    def __init__(self) -> None:
        """Start with a lookup that finds nothing."""
        super().__init__(Exception("unused"))

    async def execute(self, *_: object, **_kwargs: object) -> object:
        """Answer the lookup with no row, and the deletes with nothing."""

        class _Empty:
            def scalar_one_or_none(self) -> None:
                return None

        return _Empty()

    async def flush(self) -> None:
        """Collide the way `uq_portfolios_subject` makes a loser collide."""
        self.flushed = True
        raise IntegrityError("INSERT", (), Exception("duplicate key"))


async def test_an_integrity_error_passes_through_untranslated() -> None:
    """The race's verdict must reach the provider as itself.

    Wrapping it in `DependencyUnavailableError` would turn "somebody else
    created this portfolio first" — an ordinary, expected outcome — into a 503.
    """
    session = ConflictingSession()
    repository = PortfolioRepository(session)  # pyright: ignore[reportArgumentType]

    with pytest.raises(IntegrityError):
        await repository.replace(
            subject=SUBJECT, portfolio=seed_portfolio(as_of=FROZEN_NOW)
        )
    assert session.flushed
