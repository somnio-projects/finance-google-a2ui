"""The v1.0 agent card (ADR-M D-8, the A2UI extension spec's *Agent Card*).

Served unauthenticated at ``/a2ui/v1/.well-known/agent-card.json``, for the
reason the v0.9 card is: a renderer cannot hold a token before it has read
what the agent is. It is a second document rather than a field on the first,
because ``/.well-known/agent-card.json`` must keep answering v0.9 byte for
byte (ADR-M D-2).

The extension's ``params`` are ``agent_capabilities.json``'s ``v1.0`` object,
so a renderer learns the catalog id before it sends a word.
"""

from typing import Literal

from pydantic import BaseModel, ConfigDict, Field
from pydantic.config import JsonDict

from app.presentation.a2ui_v1.wire import CATALOG_ID, EXTENSION_URI, MIME_TYPE
from app.schemas.agent_card import AgentSkill


class ExtensionParams(BaseModel):
    """What the agent can generate under the A2UI extension."""

    model_config = ConfigDict(frozen=True, populate_by_name=True)

    supported_catalog_ids: tuple[str, ...] = Field(
        default=(CATALOG_ID,),
        alias="supportedCatalogIds",
        description="Catalogs this agent generates for; only the finance catalog.",
        examples=[[CATALOG_ID]],
    )
    accepts_inline_catalogs: bool = Field(
        default=False,
        alias="acceptsInlineCatalogs",
        description="Whether a renderer may send its own catalog; it may not.",
    )


class AgentExtension(BaseModel):
    """One A2A extension the agent supports."""

    model_config = ConfigDict(frozen=True)

    uri: str = Field(
        default=EXTENSION_URI,
        max_length=256,
        description="The extension's versioned URI.",
        examples=[EXTENSION_URI],
    )
    description: str = Field(
        default="Renders A2UI v1.0 surfaces from the finance catalog.",
        max_length=256,
        description="What activating it gives the renderer.",
    )
    required: bool = Field(
        default=False, description="Activation is optional (negotiated by metadata)."
    )
    params: ExtensionParams = Field(
        default_factory=ExtensionParams, description="`agent_capabilities` v1.0."
    )


class V1Capabilities(BaseModel):
    """Protocol features, with the A2UI extension listed."""

    model_config = ConfigDict(frozen=True, populate_by_name=True)

    streaming: bool = Field(default=True, description="`message/stream`; always.")
    push_notifications: bool = Field(
        default=False, alias="pushNotifications", description="Not supported."
    )
    extensions: tuple[AgentExtension, ...] = Field(
        default=(AgentExtension(),), description="The A2UI v1.0 extension."
    )


_EXAMPLE: JsonDict = {
    "name": "Finance A2UI agent",
    "description": "Answers portfolio questions by composing UI surfaces.",
    "url": "https://api.example.test/a2ui/v1/a2a",
    "version": "0.1.0",
    "protocolVersion": "1.0",
    "defaultInputModes": ["text/plain", MIME_TYPE],
    "defaultOutputModes": ["text/plain", MIME_TYPE],
    "capabilities": {
        "streaming": True,
        "pushNotifications": False,
        "extensions": [
            {
                "uri": EXTENSION_URI,
                "description": "Renders A2UI v1.0 surfaces from the finance catalog.",
                "required": False,
                "params": {
                    "supportedCatalogIds": [CATALOG_ID],
                    "acceptsInlineCatalogs": False,
                },
            }
        ],
    },
    "skills": [],
}


class V1AgentCard(BaseModel):
    """What a v1.0 renderer reads before it has a token."""

    model_config = ConfigDict(
        frozen=True, populate_by_name=True, json_schema_extra={"examples": [_EXAMPLE]}
    )

    name: str = Field(max_length=64, description="Agent name.")
    description: str = Field(max_length=512, description="What the agent is for.")
    url: str = Field(
        max_length=512,
        description="Where a v1.0 renderer posts: `PUBLIC_BASE_URL` + `/a2ui/v1/a2a`.",
        examples=["https://api.example.test/a2ui/v1/a2a"],
    )
    version: str = Field(max_length=64, description="Release of this agent.")
    protocol_version: Literal["1.0"] = Field(
        default="1.0",
        alias="protocolVersion",
        description="A2UI version spoken on this card's url (ADR-M).",
    )
    default_input_modes: tuple[str, ...] = Field(
        default=("text/plain", MIME_TYPE),
        alias="defaultInputModes",
        description="Prose, or an A2UI data part.",
    )
    default_output_modes: tuple[str, ...] = Field(
        default=("text/plain", MIME_TYPE),
        alias="defaultOutputModes",
        description="Prose, and A2UI data parts.",
    )
    capabilities: V1Capabilities = Field(
        default_factory=V1Capabilities, description="Protocol features."
    )
    skills: tuple[AgentSkill, ...] = Field(
        default=(), description="One per registered tool, as on the v0.9 card."
    )


__all__ = ["AgentExtension", "ExtensionParams", "V1AgentCard", "V1Capabilities"]
