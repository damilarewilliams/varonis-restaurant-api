"""Recommendation business logic — pure functions, trivially unit-testable."""

from datetime import datetime, timezone

from app.models.restaurant import Restaurant


def current_utc_hour() -> int:
    return datetime.now(timezone.utc).hour


def recommend(
    restaurants: list[Restaurant],
    style: str | None = None,
    vegetarian: bool | None = None,
    open_now: bool = False,
    at_hour: int | None = None,
) -> list[Restaurant]:
    """Filter the catalog by the requested criteria.

    - style: case-insensitive exact match
    - vegetarian: tri-state (None = don't care)
    - open_now: checks opening hours against `at_hour` (injected for
      testability; defaults to the current UTC hour)
    """
    results = restaurants
    if style is not None:
        results = [r for r in results if r.style.lower() == style.lower()]
    if vegetarian is not None:
        results = [r for r in results if r.vegetarian == vegetarian]
    if open_now:
        hour = at_hour if at_hour is not None else current_utc_hour()
        results = [r for r in results if r.is_open_at(hour)]
    return results
