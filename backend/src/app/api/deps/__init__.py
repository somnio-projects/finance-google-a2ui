"""Dependency providers, re-exported so controllers import one place.

Split into modules by the surface they serve — `common` for everything a
controller needs, `agent` for the turn — because the single file outgrew the
150-line budget once the agent host landed beside the session providers. The
import path stays `app.api.deps`, so no controller moved.
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
    "get_request_id",
    "get_session",
    "get_session_service",
    "get_tool_context",
]
