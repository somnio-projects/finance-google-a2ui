"""Who the demo portfolio belongs to, as the design names them (spec 0026 OD-1).

`Home.dc.html` greets **Alex Chen** under an avatar reading **A** and a badge
reading **Simulated portfolio**. None of that is derivable: the bearer token's
``sub`` is ``alice``, a subject for scoping and never a display name, and the
badge is a compliance statement that must read the same on every screen.

So the persona is seed data, like the lots. It is deliberately fake — no real
person, no account number — and it is one record rather than a lookup table,
because this demo has one portfolio and the design draws one name.
"""

from typing import Final

from pydantic import BaseModel, ConfigDict, Field


class DemoAccount(BaseModel):
    """The words the shell shows for the portfolio's owner."""

    model_config = ConfigDict(frozen=True)

    name: str = Field(
        min_length=1, max_length=64, description="Display name.", examples=["Alex Chen"]
    )
    initial: str = Field(
        min_length=1, max_length=2, description="Avatar monogram.", examples=["A"]
    )
    badge: str = Field(
        min_length=1,
        max_length=32,
        description="The simulation notice shown beside the name.",
        examples=["Simulated portfolio"],
    )


DEMO_ACCOUNT: Final[DemoAccount] = DemoAccount(
    name="Alex Chen", initial="A", badge="Simulated portfolio"
)


class PortfolioOwner(BaseModel):
    """Who is signed in, as the shell greets them (spec 0030)."""

    model_config = ConfigDict(frozen=True)

    name: str = Field(min_length=1, max_length=64, description="Display name.")
    initial: str = Field(min_length=1, max_length=2, description="Avatar monogram.")


def owner_from(*, display_name: str | None, email: str | None) -> PortfolioOwner | None:
    """Name the caller from what the registry and the token know (spec 0030).

    The provisioned display name wins; failing that, the part of the e-mail
    before ``@`` with its first letter raised — a name the server writes so
    the client never derives one (N-9). With neither there is no owner, and
    the shell falls back to the design's persona.
    """
    name = (display_name or "").strip() or _local_part(email)
    if not name:
        return None
    return PortfolioOwner(name=name[:64], initial=name[0].upper())


def _local_part(email: str | None) -> str:
    """The part before ``@`` with its first letter raised, or nothing."""
    if not email or "@" not in email:
        return ""
    local = email.split("@", 1)[0].strip()
    return local[:1].upper() + local[1:] if local else ""


__all__ = ["DEMO_ACCOUNT", "DemoAccount", "PortfolioOwner", "owner_from"]
