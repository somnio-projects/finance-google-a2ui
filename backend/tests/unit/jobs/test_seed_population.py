"""``--all``: naming the population instead of the people (spec 0045).

Two judgements are worth asserting, and neither is "the flag reaches the
keyword argument". The first is that the two ways of choosing owners are
**mutually exclusive** rather than one silently winning — the difference
between a run that touches one account and a run that touches every one of
them. The second is that ``--all`` reads the population from the database and
leaves the argument list entirely alone.
"""

import argparse
from collections.abc import Sequence

import pytest

from app.jobs.seed_arguments import parse_args
from app.jobs.seed_population import selected_owners


class FakeUsers:
    """A `UserRepository` that answers a fixed admitted population."""

    def __init__(self, emails: Sequence[str]) -> None:
        """Remember what the database is standing in for."""
        self._emails: list[str] = list(emails)
        self.calls: int = 0

    async def list_admitted_emails(self) -> list[str]:
        """Answer the population, counting the round trip."""
        self.calls += 1
        return list(self._emails)


def _users(*emails: str) -> FakeUsers:
    """A population double, narrowed for the call site."""
    return FakeUsers(emails)


@pytest.mark.parametrize(
    "argv",
    [["a@x.test", "--all"], []],
    ids=["a_list_and_all", "neither_a_list_nor_all"],
)
def test_parse_args_refuses_an_ambiguous_selection(argv: list[str]) -> None:
    # Both are refusals rather than a precedence rule: an operator who typed a
    # list *and* --all meant one of two very different runs, and guessing which
    # is the difference between touching one account and touching all of them.
    with pytest.raises(SystemExit):
        parse_args(argv)


@pytest.mark.parametrize(
    ("argv", "all_owners", "reset"),
    [
        (["--all"], True, False),
        (["--all", "--reset"], True, True),
        (["a@x.test"], False, False),
    ],
    ids=["all_alone", "all_and_reset", "a_list_is_still_accepted"],
)
def test_parse_args_reads_the_selection(
    argv: list[str], all_owners: bool, reset: bool
) -> None:
    args: argparse.Namespace = parse_args(argv)
    assert args.all_owners is all_owners
    assert args.reset is reset


async def test_selected_owners_reads_the_population_when_all_is_asked_for() -> None:
    users = _users("a@x.test", "b@y.test")

    chosen = await selected_owners(
        users,  # pyright: ignore[reportArgumentType]
        owners=["someone-else@z.test"],
        all_owners=True,
    )

    # The argument list is not merged in behind the flag's back.
    assert chosen == ["a@x.test", "b@y.test"]
    assert users.calls == 1


async def test_selected_owners_never_asks_the_database_for_a_named_list() -> None:
    users = _users("ignored@x.test")

    chosen = await selected_owners(
        users,  # pyright: ignore[reportArgumentType]
        owners=["named@x.test"],
        all_owners=False,
    )

    assert chosen == ["named@x.test"]
    assert users.calls == 0
