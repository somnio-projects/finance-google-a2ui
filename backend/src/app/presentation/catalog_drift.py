"""How a generated artefact reports that the checked-in copy is stale.

Extracted from ``catalog_doc`` when the union of GGU-53 and GGU-78 took that
module past the 150-line budget. The boundary is real rather than arithmetic:
rendering the contract is about the registry, while reporting drift is about
two strings and knows nothing of projections — which is why both artefacts,
the Markdown and the JSON, share this one function through
``catalog_artifacts.Rendered.drift``.
"""

from difflib import unified_diff

from app.presentation.catalog_doc import CONTRACT_PATH


def contract_drift(
    *, checked_in: str, generated: str, path: str = CONTRACT_PATH
) -> str:
    """Return a unified diff of the two, empty when the file is current.

    Args:
        checked_in: What the checked-in artefact holds today.
        generated: What the registry says it should hold.
        path: The artefact compared, named in the diff header.

    Returns:
        A diff a developer can read, or ``""`` when nothing drifted.
    """
    return "".join(
        unified_diff(
            checked_in.splitlines(keepends=True),
            generated.splitlines(keepends=True),
            fromfile=path,
            tofile="generated from the registry",
        )
    )


__all__ = ["contract_drift"]
