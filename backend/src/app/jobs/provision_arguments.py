"""What the provisioning job accepts on its command line.

Its own module for the reason `seed_arguments` is one: parsing is pure and
testable without a database, and the job that writes is a different concern
from the one that decides who was asked for.

`owners_from` is **reused** from `seed_arguments` rather than copied. The two
jobs take the same kind of list — addresses, comma-separable, lower-cased,
de-duplicated, rejected loudly on a typo — and a second copy of that
normalisation is a second place for the rules to drift.
"""

import argparse
from collections.abc import Sequence


def parse_args(argv: Sequence[str] | None = None) -> argparse.Namespace:
    """Read the address list off the command line.

    There is no `--reset` here, and its absence is a ruling: this job never
    changes a row it finds. A `revoked` account is an offboarding somebody
    performed, and a flag that undid it would be a way back in that no audit
    reader would expect (spec 0041 OD-2).
    """
    parser = argparse.ArgumentParser(
        prog="python -m app.jobs.provision_users",
        description="Add named people to the provisioning registry as members.",
    )
    parser.add_argument(
        "emails",
        nargs="+",
        help="E-mail addresses; a comma inside one separates further ones.",
    )
    return parser.parse_args(argv)


__all__ = ["parse_args"]
