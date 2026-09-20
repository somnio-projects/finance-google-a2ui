"""The A2A protocol envelope and agent card (ADR-D, ADR-J D-2).

A2A is **JSON-RPC 2.0 posted to the service root**, which contradicts the rule
that every endpoint of this service is RESTful. The two do not fight because
they live on different paths: ``/v1/**`` is ours and is REST; the root is
Google's protocol and this is its envelope. "Not REST" is not a licence for
"not documented" (ADR-J D-3), so these shapes are pydantic models with the
same field-level documentation as every other DTO.

Only the members the client SDK actually sends are modelled. A field this
service ignores is better absent than present-and-lying.
"""

from typing import Any, Literal

from pydantic import BaseModel, ConfigDict, Field

JSONRPC_VERSION = "2.0"
#: JSON-RPC reserved codes, plus the one application code this surface uses.
METHOD_NOT_FOUND = -32601
INVALID_PARAMS = -32602
UNSUPPORTED_OPERATION = -32004
#: Upper bound on top-level parameter keys. The method's own model rejects
#: anything it does not declare; this only stops an unbounded dictionary
#: reaching that model.
MAX_PARAMS = 32


class MessagePart(BaseModel):
    """One part of a client message. Only text parts are understood."""

    model_config = ConfigDict(frozen=True, extra="ignore")

    kind: Literal["text"] = Field(
        default="text", description="Part discriminator; only `text` is handled."
    )
    text: str = Field(
        max_length=4000,
        description="What the user typed.",
        examples=["why did I move?"],
    )


class ClientMessage(BaseModel):
    """The message the client sends in a `message/stream` call."""

    model_config = ConfigDict(frozen=True, extra="ignore")

    role: Literal["user"] = Field(default="user", description="Always `user`.")
    parts: tuple[MessagePart, ...] = Field(
        min_length=1, max_length=16, description="Message parts, in order."
    )
    message_id: str | None = Field(
        default=None,
        alias="messageId",
        max_length=128,
        description="Client-generated id, echoed back for correlation.",
    )
    context_id: str | None = Field(
        default=None,
        alias="contextId",
        max_length=128,
        description=(
            "Conversation the client believes this belongs to. **Never trusted "
            "on its own** — it is resolved against the authenticated subject, "
            "or treated as unknown (ADR-J D-4, ADR-A)."
        ),
    )

    def text(self) -> str:
        """Return the message's text parts joined into one prompt."""
        return " ".join(part.text for part in self.parts).strip()


class StreamParams(BaseModel):
    """Parameters of `message/stream`."""

    model_config = ConfigDict(frozen=True, extra="ignore")

    message: ClientMessage = Field(description="What the user sent.")


class JsonRpcRequest(BaseModel):
    """A JSON-RPC 2.0 request envelope."""

    model_config = ConfigDict(frozen=True, extra="ignore")

    jsonrpc: Literal["2.0"] = Field(description="Protocol version; always `2.0`.")
    id: str | int | None = Field(
        default=None,
        max_length=128,
        description=(
            "Correlation id the response echoes. Bounded because it is "
            "reflected verbatim: an unbounded id is an unbounded response."
        ),
    )
    method: str = Field(
        max_length=64,
        description="Method name, such as `message/stream`.",
        examples=["message/stream"],
    )
    params: dict[str, Any] = Field(
        default_factory=dict,
        max_length=MAX_PARAMS,
        description="Method parameters; the method's own model validates them.",
    )


class JsonRpcError(BaseModel):
    """A JSON-RPC error object.

    Distinct from the RFC 9457 problem documents `/v1/**` answers with. A
    client therefore parses two shapes depending on which surface it is on,
    which is intentional and is stated in the agent card's documentation
    (ADR-J D-3) rather than left for it to discover.
    """

    model_config = ConfigDict(frozen=True)

    code: int = Field(description="JSON-RPC error code.", examples=[METHOD_NOT_FOUND])
    message: str = Field(
        max_length=256, description="Short, safe description. Never internal text."
    )


class JsonRpcFailure(BaseModel):
    """A JSON-RPC response carrying an error."""

    model_config = ConfigDict(frozen=True)

    jsonrpc: Literal["2.0"] = Field(
        default=JSONRPC_VERSION, description="Always `2.0`."
    )
    id: str | int | None = Field(default=None, description="The request's id.")
    error: JsonRpcError = Field(description="What went wrong.")


__all__ = [
    "INVALID_PARAMS",
    "JSONRPC_VERSION",
    "MAX_PARAMS",
    "METHOD_NOT_FOUND",
    "UNSUPPORTED_OPERATION",
    "ClientMessage",
    "JsonRpcError",
    "JsonRpcFailure",
    "JsonRpcRequest",
    "MessagePart",
    "StreamParams",
]
