"""Application factory and request-logging middleware."""

import logging
import time
import uuid
from collections.abc import Awaitable, Callable
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request, Response

from app.api.routes import api_router, health_router
from app.core.config import Settings, get_settings
from app.core.logging import configure_logging, mask_sensitive

logger = logging.getLogger(__name__)


def _build_repository(settings: Settings):
    if settings.repository_backend == "dynamodb":
        from app.repositories.dynamodb import DynamoDBRestaurantRepository

        return DynamoDBRestaurantRepository(
            table_name=settings.dynamodb_table, region=settings.aws_region
        )
    from app.repositories.memory import InMemoryRestaurantRepository

    return InMemoryRestaurantRepository()


def create_app(settings: Settings | None = None) -> FastAPI:
    settings = settings or get_settings()
    configure_logging(settings.log_level)

    @asynccontextmanager
    async def lifespan(app: FastAPI):
        app.state.repository = _build_repository(settings)
        logger.info(
            "application started",
            extra={"extra_fields": {
                "event": "startup",
                "environment": settings.environment,
                "repository_backend": settings.repository_backend,
            }},
        )
        yield
        logger.info("application stopped", extra={"extra_fields": {"event": "shutdown"}})

    app = FastAPI(title=settings.app_name, lifespan=lifespan)
    app.include_router(health_router)
    app.include_router(api_router)

    @app.middleware("http")
    async def request_logging(
        request: Request, call_next: Callable[[Request], Awaitable[Response]]
    ) -> Response:
        """One structured log line per request. Query params are masked
        (defense in depth — no sensitive keys are expected in this API,
        but the masker guarantees it), auth headers are never logged."""
        request_id = request.headers.get("x-request-id", str(uuid.uuid4()))
        start = time.perf_counter()
        response = await call_next(request)
        duration_ms = round((time.perf_counter() - start) * 1000, 2)
        logger.info(
            "request handled",
            extra={"extra_fields": {
                "event": "http_request",
                "request_id": request_id,
                "method": request.method,
                "path": request.url.path,
                "query": mask_sensitive(dict(request.query_params)),
                "status": response.status_code,
                "duration_ms": duration_ms,
            }},
        )
        response.headers["x-request-id"] = request_id
        return response

    return app


app = create_app()
