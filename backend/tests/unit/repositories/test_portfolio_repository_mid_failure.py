"""When the database dies **partway through** an operation (spec 0020).

Distinct from `test_portfolio_repository_errors.py`, where the very first
statement fails. These are the harder branches: the lookup succeeds, so the
repository is already committed to a path when the connection goes — writing
the rows, or reading a portfolio's children.

They exist because those two handlers are otherwise unreachable. A working
database never takes them, and a session that fails immediately never reaches
them either, so without a fake that fails on the *n*-th statement they would
ship having never run.
"""

import pytest
from sqlalchemy.exc import OperationalError

from app.core.errors import DependencyUnavailableError
from app.domain.seed import seed_portfolio
from app.models.portfolio import Portfolio
from app.repositories.portfolio_repository import PortfolioRepository
from tests.conftest import FROZEN_NOW

SUBJECT = "subject-mid"


def _driver_error() -> OperationalError:
    """Return the exception a dropped PostgreSQL connection produces."""
    return OperationalError("SELECT 1", (), Exception("connection lost"))


class _Result:
    """The slice of a SQLAlchemy result these paths touch."""

    def __init__(self, row: object | None) -> None:
        self._row = row

    def scalar_one_or_none(self) -> object | None:
        """Return the single row, or ``None``."""
        return self._row

    def scalars(self) -> "_Result":
        """Return self; `all` below is what the caller actually wants."""
        return self

    def all(self) -> list[object]:
        """Return no children."""
        return []


class FailsAfter:
    """A session that answers ``ok`` statements, then loses the connection."""

    def __init__(self, *, ok: int, row: object | None = None) -> None:
        """Answer ``ok`` statements with ``row``, then raise."""
        self._ok = ok
        self._row = row
        self.calls = 0

    async def execute(self, *_: object, **_kwargs: object) -> object:
        """Answer while there are answers left, then fail like a dead socket."""
        self.calls += 1
        if self.calls > self._ok:
            raise _driver_error()
        return _Result(self._row)

    def add(self, *_: object) -> None:
        """Accept the entity."""

    def add_all(self, *_: object) -> None:
        """Accept the entities."""

    async def flush(self) -> None:
        """Flush without failing; the failure comes from a statement."""

    def begin_nested(self) -> object:
        """Return a savepoint context that does nothing."""

        class _Savepoint:
            async def __aenter__(self) -> None:
                return None

            async def __aexit__(self, *_: object) -> bool:
                return False

        return _Savepoint()


async def test_a_write_that_fails_after_the_lookup_is_named_a_write_failure() -> None:
    """The lookup succeeded, so this is not a read problem and must not say so.

    An operator reading `database read failed` while the *write* was what
    broke looks in the wrong place.
    """
    session = FailsAfter(ok=1)
    repository = PortfolioRepository(session)  # pyright: ignore[reportArgumentType]

    with pytest.raises(DependencyUnavailableError, match="database write failed"):
        await repository.replace(
            subject=SUBJECT, portfolio=seed_portfolio(as_of=FROZEN_NOW)
        )
    assert session.calls > 1


async def test_a_failure_reading_the_children_is_reported_not_returned_empty() -> None:
    """A portfolio with unreadable lots must raise, never look like an empty one.

    Returning no rows would produce a valid-looking portfolio with nothing in
    it — a wrong answer that no test downstream could distinguish from a
    genuinely empty one.
    """
    row = Portfolio(subject=SUBJECT, as_of=FROZEN_NOW)
    session = FailsAfter(ok=1, row=row)
    repository = PortfolioRepository(session)  # pyright: ignore[reportArgumentType]

    with pytest.raises(DependencyUnavailableError, match="database read failed"):
        await repository.find(subject=SUBJECT)
