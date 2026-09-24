"""Which roles Gemini's ``contents[].role`` field takes (GGU-90).

``generateContent`` does not take our vocabulary. A turn that feeds a tool
result back used to send role ``"function"``, which the API refuses outright,
so **every multi-step turn ended at a 400** reported to the client as
``dependency-unavailable`` — the tool ran, its result was rendered, and the
model was never allowed to read it.

**This list was measured against the API, not recalled from documentation.**
The provider enumerates its own accepted roles when it refuses one, which is
the measurement:

    Role 'function' is not supported. Please use a valid role:
    SYSTEM, SYSTEM_1, USER, ASSISTANT, DEVELOPER, CONTEXT, USER_CONTEXT,
    MODEL, USER.

``function`` is not among them, and there is no tool role at all: a
``functionResponse`` **part** travels under role ``"user"``, which is the one
combination that answers ``200``. Re-measure by sending one content with the
role in question and reading what comes back; the refusal names the whole
accepted set in one go.

The wire is **case-insensitive** on this field: we send ``"user"`` and
``"model"`` in lower case and have always been answered ``200``, while the
refusal prints the set in upper case. The set is stored as the provider
printed it and compared case-insensitively, so neither spelling is privileged
by us. The mapping that applies it is ``payload.py``.
"""

from typing import Final

#: Accepted — measured 2026-09-20 against ``gemini-3.8-flash`` on ``v1beta``,
#: quoted from the provider's own refusal. Stored upper case exactly as it
#: printed them; compare with ``.upper()``.
ACCEPTED_ROLES: Final[frozenset[str]] = frozenset(
    {
        "SYSTEM",
        "SYSTEM_1",
        "USER",
        "ASSISTANT",
        "DEVELOPER",
        "CONTEXT",
        "USER_CONTEXT",
        "MODEL",
    }
)

#: Refused — the role this adapter sent until GGU-90, kept as a fact of its
#: own so a test can assert we never emit it again, instead of re-deriving
#: the answer from the allow-list it is meant to check.
REFUSED_ROLES: Final[frozenset[str]] = frozenset({"FUNCTION"})

__all__ = ["ACCEPTED_ROLES", "REFUSED_ROLES"]
