"""Composition root: the one place that knows every concrete class.

``create_app`` builds the object graph from ``Settings`` and returns a ready
FastAPI application. Tests call it with their own settings and overrides.
"""

from collections.abc import AsyncGenerator, Callable
from contextlib import AbstractAsyncContextManager, asynccontextmanager
from datetime import timedelta

import structlog
from fastapi import FastAPI

from app import __version__
from app.agent.registry import load_tools
from app.api.container import AgentRuntime, Container
from app.api.errors import register_error_handlers
from app.api.middleware.install import install_middleware
from app.api.openapi import API_DESCRIPTION, TAGS_METADATA
from app.api.openapi_document import install as install_openapi
from app.api.router import api_router
from app.auth.registry import build_token_verifier
from app.core.config import Settings, get_settings
from app.core.logging import configure_logging, get_logger
from app.core.protocols import Clock, ErrorReporter, ModelClient, TokenVerifier
from app.core.release import resolve_release
from app.helpers.clock import SystemClock
from app.infra.db.engine import DatabaseReadinessProbe, create_engine
from app.infra.db.session import create_session_factory
from app.infra.model.factory import build_model_client
from app.infra.telemetry.factory import build_error_reporter
from app.presentation.registry import REGISTRY
from app.services.agent_card_service import build_agent_card
from app.services.feature_flag_cache import FeatureFlagCache
from app.services.health_service import HealthService
from app.services.prompt_service import build_system_prompt
from app.services.user_bootstrap import provision_admins

log: structlog.stdlib.BoundLogger = get_logger(__name__)


def build_container(
    settings: Settings,
    *,
    clock: Clock | None = None,
    reporter: ErrorReporter | None = None,
    verifier: TokenVerifier | None = None,
    model: ModelClient | None = None,
) -> Container:
    """Wire the singletons; optional arguments let tests inject doubles."""
    clock = clock or SystemClock()
    release = resolve_release(settings.app_release)
    reporter = reporter or build_error_reporter(settings, release=release)
    verifier = verifier or build_token_verifier(settings, clock)
    model = model or build_model_client(settings)
    tools = load_tools()
    prompt = build_system_prompt(tools=tools, views=REGISTRY.all())
    engine = create_engine(settings)
    return Container(
        settings=settings,
        clock=clock,
        reporter=reporter,
        verifier=verifier,
        engine=engine,
        session_factory=create_session_factory(engine),
        health=HealthService(version=release, probes=[DatabaseReadinessProbe(engine)]),
        flag_cache=FeatureFlagCache(
            ttl=timedelta(seconds=settings.feature_flags_cache_ttl_seconds), clock=clock
        ),
        agent=AgentRuntime(
            model=model,
            tools=tools,
            system_prompt=prompt,
            card=build_agent_card(settings, tools, version=__version__),
        ),
    )


def _build_lifespan(
    container: Container,
) -> Callable[[FastAPI], AbstractAsyncContextManager[None]]:
    """Log startup/shutdown and release the engine when the app stops."""

    @asynccontextmanager
    async def lifespan(_: FastAPI) -> AsyncGenerator[None]:
        """Log startup, yield control, then release the engine on shutdown."""
        log.info("startup", public_base_url=container.settings.public_base_url)
        await provision_admins(
            emails=container.settings.auth_bootstrap_admins,
            session_factory=container.session_factory,
        )
        yield
        await container.engine.dispose()
        log.info("shutdown")

    return lifespan


def _configure_app(app: FastAPI, container: Container) -> None:
    """Attach state, middleware, error handlers and routes — in that order."""
    app.state.container = container
    install_middleware(app, container)
    register_error_handlers(app, container.reporter)
    app.include_router(api_router)
    # Last: the document builder reads the routes it has just been handed
    # (spec 0038 OD-2). It is lazy, so nothing is built here.
    install_openapi(app)


def create_app(
    settings: Settings | None = None, *, container: Container | None = None
) -> FastAPI:
    """Build the application from ``settings`` (or the environment)."""
    settings = settings or get_settings()
    configure_logging(settings.log_level)
    container = container or build_container(settings)
    app = FastAPI(
        title=settings.app_name,
        version=__version__,
        description=API_DESCRIPTION,
        openapi_tags=TAGS_METADATA,
        license_info={
            "name": "Apache-2.0",
            "url": "https://www.apache.org/licenses/LICENSE-2.0",
        },
        lifespan=_build_lifespan(container),
        docs_url=None if settings.is_production else "/docs",
        redoc_url=None,
        openapi_url=None if settings.is_production else "/openapi.json",
    )
    _configure_app(app, container)
    return app


__all__ = ["build_container", "create_app"]
