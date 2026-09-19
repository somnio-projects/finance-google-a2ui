"""Composition root: the one place that knows every concrete class.

``create_app`` builds the object graph from ``Settings`` and returns a ready
FastAPI application. Tests call it with their own settings and overrides.
"""

from collections.abc import AsyncGenerator, Callable
from contextlib import AbstractAsyncContextManager, asynccontextmanager
from datetime import timedelta

import structlog
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.trustedhost import TrustedHostMiddleware

from app import __version__
from app.agent.registry import load_tools
from app.api.container import AgentRuntime, Container
from app.api.errors import register_error_handlers
from app.api.middleware.body_limit import BodyLimitMiddleware
from app.api.middleware.rate_limit import FixedWindowLimiter, RateLimitMiddleware
from app.api.middleware.request_id import RequestIdMiddleware
from app.api.middleware.security_headers import SecurityHeadersMiddleware
from app.api.openapi import API_DESCRIPTION, TAGS_METADATA
from app.api.router import api_router
from app.auth.registry import build_token_verifier
from app.core.config import Settings, get_settings
from app.core.logging import configure_logging, get_logger
from app.core.protocols import Clock, ErrorReporter, ModelClient, TokenVerifier
from app.domain.provider import InMemoryPortfolioProvider
from app.helpers.clock import SystemClock
from app.infra.db.engine import DatabaseReadinessProbe, create_engine
from app.infra.db.session import create_session_factory
from app.infra.model.factory import build_model_client
from app.infra.telemetry.factory import build_error_reporter
from app.presentation.registry import REGISTRY
from app.services.feature_flag_cache import FeatureFlagCache
from app.services.health_service import HealthService
from app.services.prompt_service import build_system_prompt

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
    reporter = reporter or build_error_reporter(settings, release=__version__)
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
        health=HealthService(
            version=__version__, probes=[DatabaseReadinessProbe(engine)]
        ),
        flag_cache=FeatureFlagCache(
            ttl=timedelta(seconds=settings.feature_flags_cache_ttl_seconds), clock=clock
        ),
        agent=AgentRuntime(model=model, tools=tools, system_prompt=prompt),
        portfolio=InMemoryPortfolioProvider(clock=clock),
    )


def _install_middleware(app: FastAPI, container: Container) -> None:
    """Order matters: outermost first (request id) to innermost (rate limit)."""
    settings = container.settings
    app.add_middleware(
        RateLimitMiddleware,
        limiter=FixedWindowLimiter(
            limit=settings.rate_limit_per_minute, clock=container.clock
        ),
    )
    app.add_middleware(BodyLimitMiddleware, max_bytes=settings.max_request_body_bytes)
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_allowed_origins,
        allow_credentials=True,
        allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
        allow_headers=["Authorization", "Content-Type", "X-Request-ID"],
    )
    app.add_middleware(TrustedHostMiddleware, allowed_hosts=settings.trusted_hosts)
    app.add_middleware(SecurityHeadersMiddleware, enable_hsts=settings.is_production)
    app.add_middleware(RequestIdMiddleware)


def _build_lifespan(
    container: Container,
) -> Callable[[FastAPI], AbstractAsyncContextManager[None]]:
    """Log startup/shutdown and release the engine when the app stops."""

    @asynccontextmanager
    async def lifespan(_: FastAPI) -> AsyncGenerator[None]:
        """Log startup, yield control, then release the engine on shutdown."""
        log.info("startup", public_base_url=container.settings.public_base_url)
        yield
        await container.engine.dispose()
        log.info("shutdown")

    return lifespan


def _configure_app(app: FastAPI, container: Container) -> None:
    """Attach state, middleware, error handlers and routes — in that order."""
    app.state.container = container
    _install_middleware(app, container)
    register_error_handlers(app, container.reporter)
    app.include_router(api_router)


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
