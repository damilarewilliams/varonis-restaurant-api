"""Endpoint tests: health surface, response contract, validation."""


def test_liveness(client):
    for path in ("/health", "/health/live"):
        response = client.get(path)
        assert response.status_code == 200
        assert response.json() == {"status": "ok"}


def test_readiness(client):
    response = client.get("/health/ready")
    assert response.status_code == 200
    assert response.json() == {"status": "ready"}


def test_recommendations_response_contract(client):
    """Matches the assignment's example exactly: a SINGLE object under
    restaurantRecommendation, camelCase keys, hours as HH:MM strings."""
    response = client.get("/api/v1/recommendations")
    assert response.status_code == 200
    body = response.json()
    assert "restaurantRecommendation" in body
    rec = body["restaurantRecommendation"]
    assert isinstance(rec, dict)  # one recommendation, not a list
    assert set(rec) == {"name", "style", "address", "openHour", "closeHour", "vegetarian"}
    assert len(rec["openHour"]) == 5 and rec["openHour"][2] == ":"   # "09:00"
    assert len(rec["closeHour"]) == 5 and rec["closeHour"][2] == ":"


def test_filter_by_style(client):
    body = client.get("/api/v1/recommendations", params={"style": "italian"}).json()
    assert body["restaurantRecommendation"]["style"].lower() == "italian"


def test_filter_by_vegetarian(client):
    body = client.get("/api/v1/recommendations", params={"vegetarian": "true"}).json()
    assert body["restaurantRecommendation"]["vegetarian"] is True


def test_combined_filters(client):
    rec = client.get(
        "/api/v1/recommendations", params={"style": "Italian", "vegetarian": "true"}
    ).json()["restaurantRecommendation"]
    assert rec["style"] == "Italian" and rec["vegetarian"] is True


def test_no_match_returns_404(client):
    response = client.get("/api/v1/recommendations", params={"style": "Martian"})
    assert response.status_code == 404
    assert "detail" in response.json()


def test_validation_rejects_bad_boolean(client):
    response = client.get("/api/v1/recommendations", params={"vegetarian": "maybe"})
    assert response.status_code == 422


def test_validation_rejects_oversized_style(client):
    response = client.get("/api/v1/recommendations", params={"style": "x" * 51})
    assert response.status_code == 422


def test_request_id_header(client):
    response = client.get("/health", headers={"x-request-id": "test-123"})
    assert response.headers["x-request-id"] == "test-123"
