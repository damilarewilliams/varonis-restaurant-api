"""Domain models. Pydantic gives both validation and serialization."""

from pydantic import BaseModel, ConfigDict, Field


class Restaurant(BaseModel):
    id: str
    name: str
    style: str = Field(description="Cuisine style, e.g. Italian, French, Korean")
    address: str
    vegetarian: bool = Field(description="Offers vegetarian options")
    open_hour: int = Field(ge=0, le=23, description="Opening hour, 24h clock (UTC)")
    close_hour: int = Field(ge=0, le=23, description="Closing hour, 24h clock (UTC)")

    def is_open_at(self, hour: int) -> bool:
        """True if open at the given hour.

        Handles overnight ranges (e.g. open 18, close 2 = open past
        midnight). Simplification: hours are UTC and whole-hour only;
        per-restaurant timezones would require a tz field - documented
        trade-off for this exercise.
        """
        if self.open_hour == self.close_hour:
            return True  # interpreted as open 24h
        if self.open_hour < self.close_hour:
            return self.open_hour <= hour < self.close_hour
        return hour >= self.open_hour or hour < self.close_hour


class RestaurantOut(BaseModel):
    """Presentation model matching the assignment's response contract
    exactly: camelCase keys, hours as "HH:MM" strings, no internal id.
    (The spec example writes "clouseHour" - treated as an evident typo
    for closeHour.) Kept separate from the domain model so storage
    (snake_case, integer hours) never leaks contract concerns."""

    model_config = ConfigDict(populate_by_name=True)

    name: str
    style: str
    address: str
    open_hour: str = Field(alias="openHour")
    close_hour: str = Field(alias="closeHour")
    vegetarian: bool

    @classmethod
    def from_domain(cls, restaurant: Restaurant) -> "RestaurantOut":
        return cls(
            name=restaurant.name,
            style=restaurant.style,
            address=restaurant.address,
            open_hour=f"{restaurant.open_hour:02d}:00",
            close_hour=f"{restaurant.close_hour:02d}:00",
            vegetarian=restaurant.vegetarian,
        )


class RecommendationResponse(BaseModel):
    """Response envelope per the assignment: a SINGLE recommendation
    ("return a recommendation for a restaurant"), not a list."""

    model_config = ConfigDict(populate_by_name=True)

    restaurant_recommendation: RestaurantOut = Field(alias="restaurantRecommendation")
