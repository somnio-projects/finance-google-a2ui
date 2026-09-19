"""The agent card: how a client discovers this agent (ADR-D D-7).

Served unauthenticated at `/.well-known/agent-card.json`, because a client
cannot present a token before it has bootstrapped.

**The url is the public one.** ADR-D D-7 exists because the sample advertised
`http://0.0.0.0:8080` — the bind address, not an address any client can reach.
It comes from `PUBLIC_BASE_URL`, which is independent of host and port.
"""

from typing import Literal

from pydantic import BaseModel, ConfigDict, Field

A2A_VERSION = "0.9"


class AgentCapabilities(BaseModel):
    """What this agent can do, as the client SDK asks."""

    model_config = ConfigDict(frozen=True)

    streaming: bool = Field(
        default=True,
        description="Whether `message/stream` is supported. Always true here.",
    )
    push_notifications: bool = Field(
        default=False,
        alias="pushNotifications",
        description="Server-initiated pushes; not supported.",
    )
    state_transition_history: bool = Field(
        default=False,
        alias="stateTransitionHistory",
        description="Replay of past task states; not supported.",
    )


class AgentSkill(BaseModel):
    """One thing a user can ask this agent for."""

    model_config = ConfigDict(frozen=True)

    id: str = Field(max_length=64, description="Stable skill id.")
    name: str = Field(max_length=64, description="Human-readable name.")
    description: str = Field(max_length=512, description="What it answers.")
    tags: tuple[str, ...] = Field(default=(), description="Discovery tags.")


class AgentCard(BaseModel):
    """What a client reads before it has a token."""

    model_config = ConfigDict(frozen=True, populate_by_name=True)

    name: str = Field(max_length=64, description="Agent name.")
    description: str = Field(max_length=512, description="What the agent is for.")
    url: str = Field(
        max_length=512,
        description=(
            "Public base URL clients post to. From `PUBLIC_BASE_URL`, never "
            "derived from the bind address (ADR-D D-7)."
        ),
        examples=["https://api.example.test"],
    )
    version: str = Field(max_length=64, description="Release of this agent.")
    protocol_version: Literal["0.9"] = Field(
        default=A2A_VERSION,
        alias="protocolVersion",
        description="A2UI version spoken. v0.9 only (ADR-D D-2).",
    )
    default_input_modes: tuple[str, ...] = Field(
        default=("text/plain",),
        alias="defaultInputModes",
        description="Accepted input media types.",
    )
    default_output_modes: tuple[str, ...] = Field(
        default=("text/plain", "application/json"),
        alias="defaultOutputModes",
        description="Produced output media types.",
    )
    capabilities: AgentCapabilities = Field(
        default_factory=AgentCapabilities, description="Supported protocol features."
    )
    skills: tuple[AgentSkill, ...] = Field(
        default=(), description="What a user can ask for, one per registered tool."
    )


__all__ = ["A2A_VERSION", "AgentCapabilities", "AgentCard", "AgentSkill"]
