"""Health and readiness response models."""

from http import HTTPStatus
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field


class HealthResponse(BaseModel):
    """Liveness answer — the process is up; nothing downstream is probed."""

    model_config = ConfigDict(
        frozen=True,
        json_schema_extra={"examples": [{"status": "ok", "version": "0.1.0"}]},
    )

    status: Literal["ok"] = Field(default="ok", description="Always `ok` when served.")
    version: str = Field(
        description=(
            "Release identifier of the running revision: `APP_RELEASE` when the "
            "delivery pipeline injected one, otherwise the packaged version."
        ),
        examples=["0.1.0+a1b2c3d"],
    )


class DependencyStatus(BaseModel):
    """Readiness of one dependency."""

    model_config = ConfigDict(frozen=True)

    name: str = Field(description="Probe name.", examples=["database"])
    ready: bool = Field(
        description="Whether that dependency answered.", examples=[True]
    )


class ReadinessResponse(BaseModel):
    """Readiness answer aggregating every probe."""

    model_config = ConfigDict(
        frozen=True,
        json_schema_extra={
            "examples": [
                {
                    "status": "ready",
                    "dependencies": [{"name": "database", "ready": True}],
                }
            ]
        },
    )

    status: Literal["ready", "degraded"] = Field(
        description="`ready` when every probe passed, `degraded` otherwise (503).",
        examples=["ready"],
    )
    dependencies: list[DependencyStatus] = Field(
        default_factory=list, description="Per-dependency readiness."
    )

    @property
    def http_status(self) -> int:
        """HTTP status the controller answers with (200 ready, 503 degraded)."""
        mapping = {"ready": HTTPStatus.OK, "degraded": HTTPStatus.SERVICE_UNAVAILABLE}
        return mapping[self.status].value


__all__ = ["DependencyStatus", "HealthResponse", "ReadinessResponse"]
