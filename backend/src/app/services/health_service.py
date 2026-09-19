"""Liveness and readiness use cases."""

import asyncio
from collections.abc import Sequence

from app.core.protocols import ReadinessProbe
from app.schemas.health import DependencyStatus, HealthResponse, ReadinessResponse


class HealthService:
    """Answer health questions from a list of injected probes."""

    def __init__(self, *, version: str, probes: Sequence[ReadinessProbe]) -> None:
        """Bind the service to the app version and its dependency probes."""
        self._version = version
        self._probes = probes

    def liveness(self) -> HealthResponse:
        """Report that the process is alive; never touches dependencies."""
        return HealthResponse(version=self._version)

    async def readiness(self) -> ReadinessResponse:
        """Run every probe concurrently and aggregate the result."""
        results = await asyncio.gather(*(probe.check() for probe in self._probes))
        dependencies = [
            DependencyStatus(name=probe.name, ready=ready)
            for probe, ready in zip(self._probes, results, strict=True)
        ]
        status = "ready" if all(results) else "degraded"
        return ReadinessResponse(status=status, dependencies=dependencies)


__all__ = ["HealthService"]
