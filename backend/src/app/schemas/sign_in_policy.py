"""The sign-in policy DTO (spec 0043): which door this deployment has.

One enumerated value, read before anybody has a token. It says what happens
to a verified identity the registry has never seen — which is the only thing
the sign-in screen needs in order to stop guessing (spec 0040 §5).
"""

from typing import Final, Literal

from pydantic import BaseModel, ConfigDict, Field

#: The two doors a deployment can have. A third is plausible — enrolment
#: restricted to a domain was discussed for the demo and not built — and a
#: Literal leaves room for it where a boolean would have to become one.
Enrolment = Literal["open", "invite-only"]

#: A verified identity the registry has never seen is admitted and enrolled.
OPEN: Final[Enrolment] = "open"
#: Only an `invited` or `active` account may in; everyone else may ask.
INVITE_ONLY: Final[Enrolment] = "invite-only"


class SignInPolicy(BaseModel):
    """``GET /v1/sign-in-policy`` — whether this deployment enrols strangers."""

    model_config = ConfigDict(
        frozen=True, json_schema_extra={"examples": [{"enrolment": OPEN}]}
    )

    enrolment: Enrolment = Field(
        description=(
            "`open` — a verified identity the registry has never seen is "
            "admitted and enrolled on its first call. `invite-only` — only an "
            "`invited` or `active` account may in; everyone else is refused "
            "and may ask through `POST /v1/access-requests`."
        ),
        examples=[OPEN, INVITE_ONLY],
    )

    @classmethod
    def of(cls, *, open_enrolment: bool) -> "SignInPolicy":
        """Name the door the ``AUTH_OPEN_ENROLMENT`` switch is currently in.

        Args:
            open_enrolment: ``Settings.auth_open_enrolment``.

        Returns:
            The policy this deployment answers with.
        """
        return cls(enrolment=OPEN if open_enrolment else INVITE_ONLY)


__all__ = ["INVITE_ONLY", "OPEN", "Enrolment", "SignInPolicy"]
