"""The fixed strings of the v1.0 wire, spelled once (ADR-M D-3, D-5, D-8).

Every one of these is a literal some other party compares byte for byte — the
renderer matches ``CATALOG_ID``, the A2A layer matches ``MIME_TYPE`` and
``EXTENSION_URI``, the schemas pin ``MESSAGE_VERSION`` — so none of them is
ever written a second time anywhere in ``src/``.
"""

from typing import Final

#: The catalog this agent generates for (ADR-M D-5). Not a resolvable URL: an
#: identifier, conventionally a URI, used as both ``$id`` and ``catalogId``.
CATALOG_ID: Final[str] = (
    "https://somniosoftware.com/a2ui/finance-showcase/v1.0/catalog.json"
)
#: Where the generated catalog is checked in, relative to the repository root.
CATALOG_PATH: Final[str] = "docs/a2ui/v1.0/finance.catalog.json"
#: The A2UI specification version the catalog declares.
PROTOCOL_VERSION: Final[str] = "1.0"
#: The ``version`` every v1.0 message carries.
MESSAGE_VERSION: Final[str] = "v1.0"
#: What marks an A2A ``DataPart`` as carrying A2UI messages.
MIME_TYPE: Final[str] = "application/a2ui+json"
#: The A2A extension the v1.0 card advertises and a renderer activates.
EXTENSION_URI: Final[str] = "https://a2ui.org/a2a-extension/a2ui/v1.0"
#: The key inside ``a2uiRendererCapabilities`` for this protocol version.
CAPABILITIES_KEY: Final[str] = "v1.0"

#: The one function the catalog declares (ADR-M D-6).
RENDER_VIEW: Final[str] = "renderView"
#: The function-response codes the agent answers with (ADR-M D-6).
INVALID_FUNCTION_CALL: Final[str] = "INVALID_FUNCTION_CALL"
UNKNOWN_FUNCTION: Final[str] = "UNKNOWN_FUNCTION"

#: The component every surface starts from; ``createSurface`` points at it.
ROOT: Final[str] = "root"
#: A component id: UAX #31-safe, short, and never a JSON-Pointer metacharacter,
#: because it is also the data-model key the component binds (spec 0053 §5).
COMPONENT_ID_PATTERN: Final[str] = r"^[A-Za-z_][A-Za-z0-9_]{0,31}$"

__all__ = [
    "CAPABILITIES_KEY",
    "CATALOG_ID",
    "CATALOG_PATH",
    "COMPONENT_ID_PATTERN",
    "EXTENSION_URI",
    "INVALID_FUNCTION_CALL",
    "MESSAGE_VERSION",
    "MIME_TYPE",
    "PROTOCOL_VERSION",
    "RENDER_VIEW",
    "ROOT",
    "UNKNOWN_FUNCTION",
]
