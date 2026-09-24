"""The provisioning job — a demo audience decided on, not discovered.

`AUTH_OPEN_ENROLMENT` already admits an unknown identity on its first sign-in
(spec 0040), so what this job adds is the row **before** anybody signs in.

The case that matters is the one it must leave alone: an existing row, in any
status. A job that overwrote a `revoked` account would be a way back in for
somebody an admin deliberately removed, and nobody reading an audit trail
would expect a provisioning run to do that.
"""

import pytest

from app.core.errors import DependencyUnavailableError
from app.jobs import provision_users
from app.jobs.provision_arguments import parse_args
from app.jobs.provision_users import PROVISION_JOB, provision_into
from tests.unit.services.user_doubles import FakeUserRepository

NEW = "stranger@example.test"
UNREACHABLE_DSN = "postgresql+asyncpg://app:app@127.0.0.1:1/finance"


async def test_an_unknown_address_is_added_as_an_active_member() -> None:
    repo = FakeUserRepository()

    added, untouched = await provision_into(repo, emails=[NEW])  # type: ignore[arg-type]
    row = await repo.find_by_email(NEW)

    assert (added, untouched) == (1, 0)
    assert row is not None
    assert (row.role, row.status) == ("member", "active")
    # Never an admin: the first admins come from AUTH_BOOTSTRAP_ADMINS and
    # nothing else creates one (spec 0027 OD-2).
    assert row.invited_by == PROVISION_JOB


@pytest.mark.parametrize("status", ["active", "invited", "requested", "revoked"])
async def test_an_existing_row_is_left_exactly_as_it_was(status: str) -> None:
    repo = FakeUserRepository()
    await repo.upsert(
        email=NEW, display_name="Kept", role="admin", status=status, invited_by="admin"
    )

    added, untouched = await provision_into(repo, emails=[NEW])  # type: ignore[arg-type]
    row = await repo.find_by_email(NEW)

    assert (added, untouched) == (0, 1)
    assert row is not None
    # Role, status and the record of who invited them all survive.
    assert (row.role, row.status, row.invited_by) == ("admin", status, "admin")
    assert row.display_name == "Kept"


async def test_re_running_the_same_list_changes_nothing_the_second_time() -> None:
    repo = FakeUserRepository()

    first = await provision_into(repo, emails=[NEW])  # type: ignore[arg-type]
    second = await provision_into(repo, emails=[NEW])  # type: ignore[arg-type]

    assert first == (1, 0)
    assert second == (0, 1)


async def test_a_mixed_list_reports_both_counts() -> None:
    repo = FakeUserRepository()
    await repo.upsert(
        email="known@example.test",
        display_name=None,
        role="member",
        status="active",
        invited_by=None,
    )

    asked = ["known@example.test", NEW, "other@example.test"]
    added, untouched = await provision_into(repo, emails=asked)  # type: ignore[arg-type]

    assert (added, untouched) == (2, 1)


def test_the_command_line_takes_a_comma_separated_list() -> None:
    # `gcloud run jobs execute --args=a@x,b@y` hands the container one
    # argument containing a comma; that must mean two people.
    assert parse_args(["a@x.test,b@y.test"]).emails == ["a@x.test,b@y.test"]


def test_there_is_no_reset_flag_and_that_is_the_point() -> None:
    # A flag that overwrote an existing row would undo an offboarding.
    with pytest.raises(SystemExit):
        parse_args(["a@x.test", "--reset"])


async def test_main_reports_a_database_it_cannot_reach(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """A job that cannot write says so; it must not exit zero having done nothing.

    The entry point, which the loop above never reaches: settings from the
    environment, a container built from them, and the dispose in the
    `finally`. The same shape `test_seed_portfolios.py` uses, for the same
    reason — a Cloud Run job's only report is its exit code.
    """
    from app.core.config import get_settings

    get_settings.cache_clear()
    monkeypatch.setenv("DATABASE_URL", UNREACHABLE_DSN)
    monkeypatch.setenv("AUTH_ISSUER", "https://i")
    monkeypatch.setenv("AUTH_AUDIENCE", "a")
    monkeypatch.setenv("AUTH_JWT_SECRET", "x" * 48)
    monkeypatch.setenv("CORS_ALLOWED_ORIGINS", "http://localhost:3000")
    try:
        with pytest.raises(DependencyUnavailableError, match="failed"):
            await provision_users.main(["a@x.test"])
    finally:
        get_settings.cache_clear()
