# API Reference

FastAPI service; interactive OpenAPI docs at `/docs` when running.

## Endpoints

### `GET /api/v1/recommendations`

Query the restaurant catalog.

| Param | Type | Default | Notes |
|-------|------|---------|-------|
| `style` | string ≤50 | — | Cuisine, case-insensitive exact match (`italian` = `Italian`) |
| `vegetarian` | bool | — | Tri-state: omitted = don't care |
| `open_now` | bool | `false` | Against opening hours, UTC whole-hours (documented simplification) |

```bash
curl "$BASE/api/v1/recommendations?style=italian&vegetarian=true"
```

```json
{
  "restaurantRecommendation": [
    {"id": "r-001", "name": "La Trattoria", "style": "Italian",
     "address": "12 Herzl St, Tel Aviv", "vegetarian": true,
     "open_hour": 9, "close_hour": 23}
  ]
}
```

No matches returns an empty list (200). Invalid input (e.g.
`vegetarian=maybe`, `style` > 50 chars) returns **422** with a structured
pydantic error body — validation is declarative, no handler code runs.

### Health surface

`GET /health` / `GET /health/live` — liveness (process up; checks nothing
external). `GET /health/ready` — readiness (DynamoDB reachable); 503 with
`{"status": "not ready"}` on dependency failure. Semantics and consumers:
[monitoring.md](monitoring.md).

## Behavior notes

- Every response carries an `x-request-id` header (caller-supplied or
  generated) — correlate with the structured logs.
- Overnight opening hours are handled (open 22, close 6 = open at 3am).
- Backend selection: `APP_REPOSITORY_BACKEND=memory` (local, sample data)
  or `dynamodb` (cluster). Same behavior, same seed data
  (`scripts/seed_dynamodb.py` loads the canonical catalog).

## Running locally

```bash
python3 -m venv .venv && source .venv/bin/activate
pip install -e ".[dev]"
uvicorn app.main:app --reload --port 8080      # memory backend by default
pytest                                          # 18 tests
```

Or containerized: `docker compose up --build` (API on :8080).
