"""AC-7..AC-10 of spec 0023 — the do/don't pair, and where it is published.

The design catalog's Zone 3 teaches the model *when* to reach for a component,
which the generated prompt did not: it listed what each view shows and what
options it takes, so two views that both describe "the portfolio" were
indistinguishable at the moment of choosing one.

The other half of this file is the **honesty rule**. Three of the six
components have no exported design page, and the catalog says so rather than
publishing a plausible sentence written here — the same rule the compliance
corpus follows for "planned".
"""

from typing import Final

import pytest
from pydantic import ValidationError

from app.presentation.catalog_guidance import NO_GUIDANCE, guidance_note
from app.presentation.contract import catalog_entry
from app.presentation.guidance import MAX_SENTENCE, Guidance
from app.presentation.prompt import prompt_fragment
from app.presentation.published import guidance_of
from app.presentation.registry import REGISTRY
from app.schemas.view_catalog import (
    GUIDANCE_SENTENCE_MAX,
    GuidanceDescriptor,
    ViewDescriptor,
)

#: The views whose design detail page was exported (GGU-53). The other three
#: were not, so they carry no guidance — asserted, not assumed.
DESIGNED: Final[frozenset[str]] = frozenset(
    {"attribution.waterfall.v1", "scenario.comparison.v1", "taxlots.table.v1"}
)


def test_exactly_the_views_with_a_design_page_carry_guidance() -> None:
    """AC-7 — guidance is published where design wrote it, and nowhere else."""
    guided = {
        projection.id
        for projection in REGISTRY.all()
        if projection.guidance is not None
    }

    assert guided == DESIGNED


def test_guidance_of_serialises_the_pair_and_reports_its_absence() -> None:
    """AC-8 — one derivation, so no rendering writes its own `None` check."""
    guided = guidance_of(REGISTRY.get("attribution.waterfall.v1"))
    unguided = guidance_of(REGISTRY.get("payoff.curve.v1"))

    assert unguided is None
    assert guided is not None
    assert set(guided) == {"use_when", "avoid_when"}
    assert guided["use_when"].startswith("the user asks WHY")


def test_the_prompt_teaches_the_pair_for_a_designed_view() -> None:
    """AC-9 — the model is told when to pick, not only what it shows."""
    fragment = prompt_fragment(REGISTRY.all())

    assert "  use when: the user asks WHY a value changed" in fragment
    assert "  do not use for: a static breakdown of what is held now" in fragment


def test_the_prompt_omits_the_pair_entirely_for_an_undesigned_view() -> None:
    """A blank instruction is worse than a missing one, so nothing is emitted.

    Counted rather than merely absent: the fragment must carry exactly one
    pair per designed view, which a stray empty `use when:` would break.
    """
    fragment = prompt_fragment(REGISTRY.all())

    assert fragment.count("  use when: ") == len(DESIGNED)
    assert fragment.count("  do not use for: ") == len(DESIGNED)
    assert "use when: \n" not in fragment


def test_the_contract_prints_the_pair_or_names_the_gap() -> None:
    """AC-10 — the reader of the document learns which of the two it is."""
    pair = Guidance(use_when="a delta is decomposed", avoid_when="a static view")

    assert guidance_note(pair) == (
        "- **Use it when** a delta is decomposed\n- **Do not use it for** a static view"
    )
    assert guidance_note(None) == NO_GUIDANCE
    assert "may invent" in NO_GUIDANCE


def test_the_published_descriptor_matches_the_declared_pair() -> None:
    """The catalog's DTO is a second declaration of `Guidance`, so compare them.

    `schemas/` may not import `presentation` (`architecture.md`), so the
    published shape is written twice. Two declarations of one fact drift the
    moment one of them moves — a comment claiming they agree is where the hole
    hides (`.claude/rules/backend/testing.md`).
    """
    declared = Guidance.model_json_schema()["properties"]
    published = GuidanceDescriptor.model_json_schema()["properties"]

    assert set(declared) == set(published) == {"use_when", "avoid_when"}
    assert MAX_SENTENCE == GUIDANCE_SENTENCE_MAX
    for name in declared:
        assert declared[name]["maxLength"] == published[name]["maxLength"]


def test_the_catalog_serves_the_pair_through_that_descriptor() -> None:
    """A real projection's guidance validates into the published DTO."""
    entry = catalog_entry(REGISTRY.get("taxlots.table.v1"))
    served = ViewDescriptor.model_validate(entry | {"id": entry["id"]})

    assert served.guidance is not None
    assert served.guidance.use_when.startswith("the user asks about selling")
    assert (
        ViewDescriptor.model_validate(
            catalog_entry(REGISTRY.get("payoff.curve.v1"))
        ).guidance
        is None
    )


def test_a_sentence_longer_than_the_bound_is_rejected() -> None:
    """Declared and bounded like every other published field (ADR-K D-3)."""
    with pytest.raises(ValidationError, match="use_when"):
        Guidance(use_when="x" * (MAX_SENTENCE + 1), avoid_when="fine")


def test_guidance_is_frozen() -> None:
    """It is published in four renderings; none of them may edit it."""
    pair = Guidance(use_when="a", avoid_when="b")

    with pytest.raises(ValidationError, match="frozen"):
        pair.use_when = "c"
