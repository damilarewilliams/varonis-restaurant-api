"""Repository port. Business logic depends on this Protocol,
never on boto3 - which is what makes the service unit-testable
without AWS and lets local dev run with zero credentials."""

from typing import Protocol

from app.models.restaurant import Restaurant


class RestaurantRepository(Protocol):
    def list_restaurants(self) -> list[Restaurant]:
        """Return all restaurants."""
        ...

    def ping(self) -> bool:
        """Cheap dependency check used by the readiness endpoint."""
        ...
