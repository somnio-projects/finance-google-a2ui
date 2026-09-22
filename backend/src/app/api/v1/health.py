"""Health controllers — unauthenticated by contract (ADR-B D-3).

The liveness path is ``/health``, not the ``/healthz`` convention it used to
be. **Google's edge intercepts the exact path ``/healthz`` on ``*.run.app``**
and answers its own HTML 404; the request never reaches the container. It was
found by deploying: the pipeline's post-shift verification failed ten times in
a row against a service that was serving fine.

Proven rather than assumed, with two controls and from two independent
networks (a laptop and a GitHub Actions runner):

===================  ==========================  =========================
path                 response                    reached the container?
===================  ==========================  =========================
``/HEALTHZ``         ``{"detail":"Not Found"}``  yes, in the request log
``/nonexistent``     ``{"detail":"Not Found"}``  yes, in the request log
``/healthz``         Google's HTML 404           **never logged**
===================  ==========================  =========================

``/health``, ``/livez``, ``/_health``, ``/healthcheck``, ``/status`` and
``/alivez`` were all probed before choosing: every one reaches the app, so the
interception is specific to ``/healthz`` and the replacement was picked on
evidence. The endpoint's behaviour, DTO and contract are unchanged — only the
string. Recorded in specs/infra/0001-dev-environment.md §10b.
"""

from typing import Annotated

from fastapi import APIRouter, Depends, Response

from app.api.deps import get_health_service
from app.api.openapi import problem_responses
from app.schemas.health import HealthResponse, ReadinessResponse
from app.services.health_service import HealthService

router = APIRouter(tags=["health"])
HealthDep = Annotated[HealthService, Depends(get_health_service)]


@router.get(
    "/health",
    response_model=HealthResponse,
    operation_id="read_liveness",
    summary="Report process liveness",
    description=(
        "Answers 200 while the process is alive. It never probes a dependency, "
        "so a database or model-provider blip cannot cause a restart loop. "
        "Unauthenticated by contract. Spec 0001 AC-1."
    ),
    # No 429: the limiter exempts the probe paths by name
    # (`middleware/rate_limit.EXEMPT_PATHS`), so documenting one described a
    # response no orchestrator can ever receive (spec 0035 OD-1).
    responses=problem_responses(500),
)
def health(service: HealthDep) -> HealthResponse:
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
        # Exempt from the rate limiter, exactly like `/health` above.
        **problem_responses(500),
    },
)
async def readyz(service: HealthDep, response: Response) -> ReadinessResponse:
    """Return 200 when every dependency is reachable, 503 otherwise."""
    result = await service.readiness()
    response.status_code = result.http_status
    return result


__all__ = ["router"]
