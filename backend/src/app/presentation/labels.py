"""The one thing every fragment is: a figure under a human label.

Its own module because both halves of the vocabulary build on it —
``fragments`` and ``plot_fragments`` — and a shared base living in either one
would make the other import it, closing a cycle the moment the split happened.
"""

from pydantic import BaseModel, ConfigDict, Field


class Labelled(BaseModel):
    """A fragment the widget shows under a human label."""

    model_config = ConfigDict(frozen=True)

    label: str = Field(
        max_length=64,
        description="Human label the widget shows.",
        examples=["NVIDIA Corp"],
    )


__all__ = ["Labelled"]
