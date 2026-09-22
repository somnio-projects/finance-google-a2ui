"""``owner_from`` — who the shell greets (spec 0030)."""

from app.domain.persona import PortfolioOwner, owner_from


def test_the_registry_display_name_wins() -> None:
    owner = owner_from(display_name="  Priya Natarajan ", email="priya@somnio.dev")

    assert owner == PortfolioOwner(name="Priya Natarajan", initial="P")


def test_an_e_mail_names_the_caller_by_its_local_part_raised() -> None:
    assert owner_from(display_name=None, email="demo@somnio.dev") == PortfolioOwner(
        name="Demo", initial="D"
    )


def test_a_blank_name_falls_back_to_the_e_mail() -> None:
    assert owner_from(display_name="   ", email="lucia@somnio.dev") == PortfolioOwner(
        name="Lucia", initial="L"
    )


def test_nothing_to_speak_of_is_no_owner() -> None:
    assert owner_from(display_name=None, email=None) is None
    assert owner_from(display_name="", email="not-an-address") is None
    assert owner_from(display_name=None, email="@somnio.dev") is None


def test_a_long_name_is_cut_to_the_field_bound() -> None:
    owner = owner_from(display_name="x" * 80, email=None)

    assert owner is not None
    assert len(owner.name) == 64
    assert owner.initial == "X"
