"""Health and readiness response models."""

from http import HTTPStatus
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field


class HealthResponse(BaseModel):
    """Liveness answer — the process is up; nothing downstream is probed."""

    model_config = ConfigDict(frozen=True)

    status: Literal["ok"] = "ok"
    version: str


class DependencyStatus(BaseModel):
    """Readiness of one dependency."""

    model_config = ConfigDict(frozen=True)

    name: str
    ready: bool


class ReadinessResponse(BaseModel):
    """Readiness answer aggregating every probe."""

    model_config = ConfigDict(frozen=True)

    status: Literal["ready", "degraded"]
    dependencies: list[DependencyStatus] = Field(default_factory=list)

    @property
    def http_status(self) -> int:
        """HTTP status the controller answers with (200 ready, 503 degraded)."""
        mapping = {"ready": HTTPStatus.OK, "degraded": HTTPStatus.SERVICE_UNAVAILABLE}
        return mapping[self.status].value


__all__ = ["DependencyStatus", "HealthResponse", "ReadinessResponse"]
