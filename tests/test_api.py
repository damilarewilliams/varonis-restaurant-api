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
    response = client.get("/api/v1/recommendations")
    assert response.status_code == 200
    body = response.json()
    assert "restaurantRecommendation" in body  # camelCase envelope
    assert len(body["restaurantRecommendation"]) > 0
    first = body["restaurantRecommendation"][0]
    assert {"id", "name", "style", "address", "vegetarian", "open_hour", "close_hour"} <= set(first)


def test_filter_by_style(client):
    body = client.get("/api/v1/recommendations", params={"style": "italian"}).json()
    results = body["restaurantRecommendation"]
    assert results and all(r["style"].lower() == "italian" for r in results)


def test_filter_by_vegetarian(client):
    body = client.get("/api/v1/recommendations", params={"vegetarian": "true"}).json()
    results = body["restaurantRecommendation"]
    assert results and all(r["vegetarian"] for r in results)


def test_combined_filters(client):
    body = client.get(
        "/api/v1/recommendations", params={"style": "Italian", "vegetarian": "true"}
    ).json()
    results = body["restaurantRecommendation"]
    assert all(r["style"] == "Italian" and r["vegetarian"] for r in results)


def test_validation_rejects_bad_boolean(client):
    response = client.get("/api/v1/recommendations", params={"vegetarian": "maybe"})
    assert response.status_code == 422


def test_validation_rejects_oversized_style(client):
    response = client.get("/api/v1/recommendations", params={"style": "x" * 51})
    assert response.status_code == 422


def test_request_id_header(client):
    response = client.get("/health", headers={"x-request-id": "test-123"})
    assert response.headers["x-request-id"] == "test-123"
