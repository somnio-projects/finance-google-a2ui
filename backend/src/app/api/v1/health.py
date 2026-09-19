"""Health controllers — unauthenticated by contract (ADR-B D-3)."""

from typing import Annotated

from fastapi import APIRouter, Depends, Response

from app.api.deps import get_health_service
from app.api.openapi import problem_responses
from app.schemas.health import HealthResponse, ReadinessResponse
from app.services.health_service import HealthService

router = APIRouter(tags=["health"])
HealthDep = Annotated[HealthService, Depends(get_health_service)]


@router.get(
    "/healthz",
    response_model=HealthResponse,
    operation_id="read_liveness",
    summary="Report process liveness",
    description=(
        "Answers 200 while the process is alive. It never probes a dependency, "
        "so a database or model-provider blip cannot cause a restart loop. "
        "Unauthenticated by contract. Spec 0001 AC-1."
    ),
    responses=problem_responses(429, 500),
)
def healthz(service: HealthDep) -> HealthResponse:
    """Return 200 while the process is alive. Never probes dependencies."""
    return service.liveness()


@router.get(
    "/readyz",
    response_model=ReadinessResponse,
    operation_id="read_readiness",
    summary="Report readiness of every dependency",
    description=(
        "Runs every registered `ReadinessProbe` (the database today) and "
        "answers 200 `ready` when all pass, or 503 `degraded` listing which "
        "dependency failed. Use it as the deployment startup probe. "
        "Unauthenticated by contract. Spec 0001 AC-2."
    ),
    responses={
        503: {
            "model": ReadinessResponse,
            "description": "At least one dependency is not ready (`degraded`).",
        },
        **problem_responses(429, 500),
    },
)
async def readyz(service: HealthDep, response: Response) -> ReadinessResponse:
    """Return 200 when every dependency is reachable, 503 otherwise."""
    result = await service.readiness()
    response.status_code = result.http_status
    return result


__all__ = ["router"]
