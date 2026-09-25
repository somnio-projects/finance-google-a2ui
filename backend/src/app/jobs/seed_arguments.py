"""What the seed job accepts on its command line (spec 0035 §4.1).

Split from `seed_portfolios.py` under the 150-line budget, along the seam
that was already there: this module decides **who** was asked for, that one
writes the portfolios. Keeping the parsing pure is also what lets the
rejection cases be unit-tested without a database.
"""

import argparse
from collections.abc import Sequence

#: The column's width (`portfolios.owner_email`), so a value this job accepts
#: is a value the database accepts.
MAX_EMAIL: int = 320


def owners_from(values: Sequence[str]) -> list[str]:
    """Normalise the requested addresses into the keys the repository uses.

    Args:
        values: The positional arguments, each possibly comma-separated.

    Returns:
        Lower-cased addresses, de-duplicated, in the order first named.

    Raises:
        ValueError: When an entry is not an address or is longer than the
            column, or when the call names none at all. A typo must stop the
            job rather than quietly seed a portfolio nobody will ever read.

            **The offending value is not in the message**, only its position:
            an exception from a Cloud Run job is a log line, and spec 0035 §5
            says an address never becomes one. The operator typed the list
            and can count to the index.
    """
    owners: list[str] = []
    position = 0
    for raw in values:
        for part in raw.split(","):
            position += 1
            email = part.strip().lower()
            if not email:
                continue
            if "@" not in email or len(email) > MAX_EMAIL:
                msg = f"argument {position} is not an e-mail address"
                raise ValueError(msg)
            if email not in owners:
                owners.append(email)
    if not owners:
        msg = "name at least one owner to seed"
        raise ValueError(msg)
    return owners


def _require_one_selection(
    parser: argparse.ArgumentParser, args: argparse.Namespace
) -> None:
    """Refuse a selection that names both ways of choosing owners, or neither.

    Both are refusals rather than a precedence rule: an operator who typed a
    list *and* ``--all`` meant one of two very different runs, and guessing
    which would be the difference between touching four accounts and touching
    every one of them.

    Raises:
        SystemExit: Through ``parser.error``, which is how argparse refuses.
    """
    if args.all_owners and args.emails:
        parser.error("name owners or pass --all, not both")
    if not args.all_owners and not args.emails:
        parser.error("name at least one owner, or pass --all")


def parse_args(argv: Sequence[str] | None = None) -> argparse.Namespace:
    """Read the owner selection and the reset flag off the command line.

    Raises:
        SystemExit: When the selection names both ways or neither; see
            :func:`_require_one_selection`.
    """
    parser = argparse.ArgumentParser(
        prog="python -m app.jobs.seed_portfolios",
        description="Give one or more owners the curated demo portfolio.",
    )
    parser.add_argument(
        "emails",
        nargs="*",
        help="Owner e-mail addresses; a comma inside one separates further ones.",
    )
    parser.add_argument(
        "--all",
        dest="all_owners",
        action="store_true",
        help=(
            "Every admitted account in this environment, read from the "
            "database instead of the command line. Excludes revoked and "
            "requested accounts. Pair with --reset to re-seed accounts that "
            "already have a portfolio."
        ),
    )
    parser.add_argument(
        "--reset",
        action="store_true",
        help="Replace an existing portfolio instead of skipping that owner.",
    )
    args = parser.parse_args(argv)
    _require_one_selection(parser, args)
    return args


__all__ = ["MAX_EMAIL", "owners_from", "parse_args"]
