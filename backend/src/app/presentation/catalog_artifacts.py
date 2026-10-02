"""Every generated catalog artefact, rendered in one pass (GGU-41, GGU-53).

The contract is published twice: as Markdown for the designer who reads it and
as JSON for the client test that loads it. They are two renderings of **one**
registry read, listed here so the generator script, the gate and the tests walk
the same list — a second artefact gated by a second script is how the two would
start disagreeing.

Adding a third rendering is one entry in ``ARTIFACTS`` and its renderer; the
script, the gate step and the drift check need no change. Everything the
generator needs — the list, the diff and the command that fixes a stale file —
is reachable from here, so it imports one module rather than three.
"""

from collections.abc import Callable, Sequence
from dataclasses import dataclass
from typing import Final

from app.presentation.a2ui_v1.catalog import catalog_document
from app.presentation.a2ui_v1.wire import CATALOG_PATH
from app.presentation.catalog_doc import (
    CONTRACT_PATH,
    contract_document,
)
from app.presentation.catalog_drift import contract_drift
from app.presentation.catalog_json import (
    FIX_COMMAND,
    SNAPSHOT_PATH,
    snapshot_document,
)
from app.presentation.registry import Projection


@dataclass(frozen=True, slots=True)
class Artifact:
    """One generated file: where it is checked in and how it is rendered."""

    path: str
    render: Callable[[Sequence[Projection]], str]


@dataclass(frozen=True, slots=True)
class Rendered:
    """One artefact beside the text the registry says it should hold."""

    path: str
    generated: str

    def drift(self, checked_in: str) -> str:
        """Return a unified diff against ``checked_in``, empty when current.

        Args:
            checked_in: What the file on disk holds, or ``""`` when it is
                missing — a missing artefact is drift, never a pass.

        Returns:
            A diff a developer can read, or ``""`` when nothing drifted.
        """
        return contract_drift(
            checked_in=checked_in, generated=self.generated, path=self.path
        )


#: Every rendering of the registry, in the order the script writes them: both
#: renderings of the frozen contract, then the A2UI v1.0 catalog (ADR-M D-5).
ARTIFACTS: Final[tuple[Artifact, ...]] = (
    Artifact(path=CONTRACT_PATH, render=contract_document),
    Artifact(path=SNAPSHOT_PATH, render=snapshot_document),
    Artifact(path=CATALOG_PATH, render=catalog_document),
)


def render_all(projections: Sequence[Projection]) -> tuple[Rendered, ...]:
    """Render every catalog artefact from one reading of the registry.

    Args:
        projections: The registry's contents, ordered by id.

    Returns:
        One ``Rendered`` per artefact, in ``ARTIFACTS`` order.
    """
    return tuple(
        Rendered(path=artifact.path, generated=artifact.render(projections))
        for artifact in ARTIFACTS
    )


__all__ = ["ARTIFACTS", "FIX_COMMAND", "Artifact", "Rendered", "render_all"]
