"""The seed job's decisions, without a database (spec 0035 §4.1, AC-10).

What is worth asserting is not "it calls the repository" — that is the
implementation restated. It is the three judgements the job makes: which
addresses it accepts, that a second run over the same list writes nothing,
and that `--reset` is the only thing that overwrites somebody's portfolio.
"""

from datetime import datetime

import pytest

from app.core.errors import DependencyUnavailableError
from app.domain.portfolio import Portfolio
from app.jobs import seed_portfolios
from app.jobs.seed_arguments import MAX_EMAIL, owners_from, parse_args
from app.jobs.seed_portfolios import seed_into
from tests.conftest import FROZEN_NOW

UNREACHABLE_DSN = "postgresql+asyncpg://app:app@127.0.0.1:1/finance"


class FakeRepository:
    """A `PortfolioRepository` that remembers per owner instead of persisting."""

    def __init__(self) -> None:
        """Start empty."""
        self.stored: dict[str, Portfolio] = {}

    async def find(self, *, owner: str) -> Portfolio | None:
        """Return what this owner has, if anything."""
        return self.stored.get(owner)

    async def replace(self, *, owner: str, portfolio: Portfolio) -> None:
        """Store it, as the real repository would."""
        self.stored[owner] = portfolio


async def _seed(
    repository: FakeRepository,
    owners: list[str],
    *,
    reset: bool = False,
    as_of: datetime = FROZEN_NOW,
) -> tuple[int, int]:
    """Run the loop under test against the double."""
    return await seed_into(
        repository,  # pyright: ignore[reportArgumentType]
        owners=owners,
        reset=reset,
        as_of=as_of,
    )


@pytest.mark.parametrize(
    ("argv", "expected"),
    [
        (["A@X.test", "b@y.test"], ["a@x.test", "b@y.test"]),
        (["a@x.test,b@y.test"], ["a@x.test", "b@y.test"]),
        (["a@x.test", " A@X.test ", "a@x.test,"], ["a@x.test"]),
    ],
    ids=["separate_arguments", "one_comma_separated", "deduplicated_and_folded"],
)
def test_owners_from_normalises_the_addresses(
    argv: list[str], expected: list[str]
) -> None:
    assert owners_from(argv) == expected


@pytest.mark.parametrize(
    ("argv", "message"),
    [
        (["not-an-address"], "argument 1 is not an e-mail address"),
        ([f"{'x' * MAX_EMAIL}@y.test"], "argument 1 is not an e-mail address"),
        (["a@x.test,nope"], "argument 2 is not an e-mail address"),
        ([","], "at least one owner"),
    ],
    ids=[
        "no_at_sign",
        "longer_than_the_column",
        "the_second_of_a_comma_list",
        "nothing_but_separators",
    ],
)
def test_owners_from_refuses_what_the_database_would_not_hold(
    argv: list[str], message: str
) -> None:
    """The message names the POSITION, never the value: it becomes a log line."""
    with pytest.raises(ValueError, match=message):
        owners_from(argv)


def test_parse_args_reads_the_owners_and_the_reset_flag() -> None:
    plain = parse_args(["a@x.test", "b@y.test"])
    assert (plain.emails, plain.reset) == (["a@x.test", "b@y.test"], False)
    assert parse_args(["--reset", "a@x.test"]).reset is True


async def test_one_run_seeds_every_owner_it_was_given() -> None:
    """Several addresses, one invocation — not N invocations (AC-10)."""
    repository = FakeRepository()

    assert await _seed(repository, ["a@x.test", "b@y.test", "c@z.test"]) == (3, 0)
    assert sorted(repository.stored) == ["a@x.test", "b@y.test", "c@z.test"]


async def test_an_owner_who_already_has_one_is_skipped_not_doubled() -> None:
    """Re-running over an overlapping list must write nothing new (AC-10)."""
    repository = FakeRepository()

    first = await _seed(repository, ["a@x.test", "b@y.test"])
    second = await _seed(repository, ["b@y.test", "c@z.test"])

    assert (first, second) == ((2, 0), (1, 1))
    assert sorted(repository.stored) == ["a@x.test", "b@y.test", "c@z.test"]


async def test_reset_replaces_an_existing_portfolio() -> None:
    repository = FakeRepository()
    await _seed(repository, ["a@x.test"])
    before = repository.stored["a@x.test"]

    again = await _seed(repository, ["a@x.test"], reset=True)

    assert again == (1, 0)
    assert repository.stored["a@x.test"] is not before


async def test_main_reports_a_database_it_cannot_reach(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """A job that cannot write says so; it must not exit zero having done nothing."""
    from app.core.config import get_settings

    get_settings.cache_clear()
    monkeypatch.setenv("DATABASE_URL", UNREACHABLE_DSN)
    monkeypatch.setenv("AUTH_ISSUER", "https://i")
    monkeypatch.setenv("AUTH_AUDIENCE", "a")
    monkeypatch.setenv("AUTH_JWT_SECRET", "x" * 48)
    monkeypatch.setenv("CORS_ALLOWED_ORIGINS", "http://localhost:3000")
    try:
        with pytest.raises(DependencyUnavailableError, match="failed"):
            await seed_portfolios.main(["a@x.test"])
    finally:
        get_settings.cache_clear()
