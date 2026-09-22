"""``provision_admins`` — the first admins come from configuration (OD-2)."""

from app.infra.db.engine import create_engine
from app.infra.db.session import create_session_factory
from app.services.user_bootstrap import ensure_admins, provision_admins
from tests.conftest import make_settings
from tests.unit.api.conftest import UNREACHABLE_DSN
from tests.unit.services.user_doubles import FakeUserRepository


async def test_nothing_configured_touches_nothing() -> None:
    engine = create_engine(make_settings(database_url=UNREACHABLE_DSN))
    try:
        assert (
            await provision_admins(
                emails=[], session_factory=create_session_factory(engine)
            )
            == 0
        )
    finally:
        await engine.dispose()


async def test_a_missing_database_is_a_warning_not_a_failed_boot() -> None:
    engine = create_engine(make_settings(database_url=UNREACHABLE_DSN))
    try:
        result = await provision_admins(
            emails=["root@somnio.dev"], session_factory=create_session_factory(engine)
        )
    finally:
        await engine.dispose()
    assert result == -1


async def test_ensure_admins_is_idempotent_and_promotes_members() -> None:
    repo = FakeUserRepository()
    await repo.upsert(
        email="m@example.test",
        display_name=None,
        role="member",
        status="active",
        invited_by=None,
    )
    assert await ensure_admins(repo, [" Root@Somnio.dev ", "m@example.test"]) == 2  # type: ignore[arg-type]
    assert repo.rows["root@somnio.dev"].invited_by == "bootstrap"
    assert (repo.rows["m@example.test"].role, repo.rows["m@example.test"].status) == (
        "admin",
        "active",
    )
    assert await ensure_admins(repo, ["root@somnio.dev"]) == 0  # type: ignore[arg-type]
