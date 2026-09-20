"""GGU-90 — every role we emit is one the provider said it accepts.

**This file exists because of how the bug survived.** The mapping was covered:
``test_payload.py`` asserted that a tool result went out under role
``"function"``, and it did, and the test passed for as long as the code was
broken. The assertion was a *copy of the mapping*, written by the same person
on the same day from the same belief, so the two could only ever agree. A
second declaration of our own guess is not a check on the guess.

What makes this different is that ``wire_roles.py`` holds an answer **the
provider gave**, quoted from its own refusal, so the comparison here is
between what we send and what the API said it takes. The tests walk
``MessageRole`` rather than a list of cases, so a role added tomorrow is
checked the day it is added rather than the day someone remembers.
"""

import pytest

from app.core.model import MessageRole
from app.infra.model.payload import ROLES
from app.infra.model.wire_roles import ACCEPTED_ROLES, REFUSED_ROLES

EVERY_ROLE = list(MessageRole)
IDS = [role.value for role in EVERY_ROLE]


@pytest.mark.parametrize("role", EVERY_ROLE, ids=IDS)
def test_every_role_we_can_emit_is_one_the_provider_accepts(role: MessageRole) -> None:
    assert ROLES[role].upper() in ACCEPTED_ROLES


@pytest.mark.parametrize("role", EVERY_ROLE, ids=IDS)
def test_no_role_we_can_emit_is_one_the_provider_refused(role: MessageRole) -> None:
    assert ROLES[role].upper() not in REFUSED_ROLES


def test_the_two_measured_lists_do_not_contradict_each_other() -> None:
    assert not (ACCEPTED_ROLES & REFUSED_ROLES)


def test_the_provider_has_no_tool_role_so_a_result_travels_as_a_user_turn() -> None:
    # The measured fact behind GGU-90: Gemini's accepted set contains nothing
    # for a tool. What marks a tool result is the functionResponse *part*, so
    # the message carrying it goes out under the same role as a question.
    assert ROLES[MessageRole.TOOL] == ROLES[MessageRole.USER]
