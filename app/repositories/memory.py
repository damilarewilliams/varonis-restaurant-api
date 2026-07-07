"""In-memory repository: local development and unit tests.
Same interface as DynamoDB — swapping backends is a config change."""

from app.models.restaurant import Restaurant

SAMPLE_RESTAURANTS: list[Restaurant] = [
    Restaurant(
        id="r-001", name="La Trattoria", style="Italian",
        address="12 Herzl St, Tel Aviv", vegetarian=True,
        open_hour=9, close_hour=23,
    ),
    Restaurant(
        id="r-002", name="Chez Marcel", style="French",
        address="4 Rothschild Blvd, Tel Aviv", vegetarian=False,
        open_hour=17, close_hour=1,  # overnight
    ),
    Restaurant(
        id="r-003", name="Seoul Kitchen", style="Korean",
        address="88 Dizengoff St, Tel Aviv", vegetarian=True,
        open_hour=11, close_hour=22,
    ),
    Restaurant(
        id="r-004", name="Green Garden", style="Vegan",
        address="7 Ibn Gabirol St, Tel Aviv", vegetarian=True,
        open_hour=8, close_hour=20,
    ),
    Restaurant(
        id="r-005", name="Pasta Bar", style="Italian",
        address="30 Allenby St, Tel Aviv", vegetarian=False,
        open_hour=12, close_hour=23,
    ),
    Restaurant(
        id="r-006", name="Night Owl Diner", style="American",
        address="2 HaYarkon St, Tel Aviv", vegetarian=False,
        open_hour=22, close_hour=6,  # overnight
    ),
]


class InMemoryRestaurantRepository:
    def __init__(self, restaurants: list[Restaurant] | None = None) -> None:
        self._restaurants = restaurants if restaurants is not None else SAMPLE_RESTAURANTS

    def list_restaurants(self) -> list[Restaurant]:
        return list(self._restaurants)

    def ping(self) -> bool:
        return True
