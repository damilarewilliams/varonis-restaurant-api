"""HTTP endpoints.

Validation is declarative: FastAPI + pydantic reject bad input with a
422 and a structured error body before any handler code runs (e.g.
vegetarian=maybe, style longer than 50 chars).
"""

import logging

from fastapi import APIRouter, Query, Request, Response, status

from app.models.restaurant import RecommendationResponse
from app.services.recommendation import recommend

logger = logging.getLogger(__name__)

health_router = APIRouter(tags=["health"])
api_router = APIRouter(prefix="/api/v1", tags=["recommendations"])


@health_router.get("/health")
@health_router.get("/health/live")
def liveness() -> dict[str, str]:
    """Liveness: the process is up and serving. Kubernetes restarts the
    container if this fails. Deliberately checks nothing external — a
    DynamoDB outage must not cause a restart storm."""
    return {"status": "ok"}


@health_router.get("/health/ready")
def readiness(request: Request, response: Response) -> dict[str, str]:
    """Readiness: dependencies reachable. Kubernetes stops routing traffic
    to this pod (without restarting it) while this fails."""
    repo = request.app.state.repository
    if repo.ping():
        return {"status": "ready"}
    response.status_code = status.HTTP_503_SERVICE_UNAVAILABLE
    return {"status": "not ready"}


@api_router.get(
    "/recommendations",
    response_model=RecommendationResponse,
    response_model_by_alias=True,
)
def get_recommendations(
    request: Request,
    style: str | None = Query(default=None, max_length=50, description="Cuisine style"),
    vegetarian: bool | None = Query(default=None, description="Vegetarian options required"),
    open_now: bool = Query(default=False, description="Only restaurants open right now (UTC)"),
) -> RecommendationResponse:
    repo = request.app.state.repository
    matches = recommend(
        repo.list_restaurants(), style=style, vegetarian=vegetarian, open_now=open_now
    )
    logger.info(
        "recommendation served",
        extra={"extra_fields": {
            "event": "recommendation",
            "filters": {"style": style, "vegetarian": vegetarian, "open_now": open_now},
            "result_count": len(matches),
        }},
    )
    return RecommendationResponse(restaurant_recommendation=matches)
