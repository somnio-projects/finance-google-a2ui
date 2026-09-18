"""Health controllers — unauthenticated by contract (ADR-B D-3)."""

from typing import Annotated

from fastapi import APIRouter, Depends, Response

from app.api.deps import get_health_service
from app.schemas.health import HealthResponse, ReadinessResponse
from app.services.health_service import HealthService

router = APIRouter(tags=["health"])
HealthDep = Annotated[HealthService, Depends(get_health_service)]


@router.get("/healthz", response_model=HealthResponse, summary="Liveness")
def healthz(service: HealthDep) -> HealthResponse:
    """Return 200 while the process is alive. Never probes dependencies."""
    return service.liveness()


@router.get("/readyz", response_model=ReadinessResponse, summary="Readiness")
async def readyz(service: HealthDep, response: Response) -> ReadinessResponse:
    """Return 200 when every dependency is reachable, 503 otherwise."""
    result = await service.readiness()
    response.status_code = result.http_status
    return result


__all__ = ["router"]
