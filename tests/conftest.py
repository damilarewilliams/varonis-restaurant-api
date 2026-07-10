import pytest
from fastapi.testclient import TestClient

from app.core.config import Settings
from app.main import create_app


@pytest.fixture
def client() -> TestClient:
    """App wired to the in-memory repository - no AWS involved."""
    settings = Settings(environment="test", repository_backend="memory")
    app = create_app(settings)
    with TestClient(app) as test_client:  # context manager runs lifespan
        yield test_client
