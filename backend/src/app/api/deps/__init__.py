"""Every FastAPI dependency provider, re-exported from one name.

Controllers import ``from app.api.deps import ...`` exactly as before; the
providers are grouped into modules only because the single file outgrew the
150-line budget. The rule is unchanged: services are constructed here and
nowhere else, so the wiring stays visible in one place.
"""

from app.api.deps.agent import get_agent_service, get_tool_context
from app.api.deps.common import (
    ContainerDep,
    PrincipalDep,
    RequestIdDep,
    SessionDep,
    get_audit_service,
    get_auth_service,
    get_container,
    get_current_principal,
    get_feature_flag_service,
    get_health_service,
    get_identity_service,
    get_request_id,
    get_session,
    get_session_service,
)
from app.api.deps.views import get_render_intent_service, get_view_service

__all__ = [
    "ContainerDep",
    "PrincipalDep",
    "RequestIdDep",
    "SessionDep",
    "get_agent_service",
    "get_audit_service",
    "get_auth_service",
    "get_container",
    "get_current_principal",
    "get_feature_flag_service",
    "get_health_service",
    "get_identity_service",
    "get_render_intent_service",
    "get_request_id",
    "get_session",
    "get_session_service",
    "get_tool_context",
    "get_view_service",
]
