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
        per-restaurant timezones would require a tz field — documented
        trade-off for this exercise.
        """
        if self.open_hour == self.close_hour:
            return True  # interpreted as open 24h
        if self.open_hour < self.close_hour:
            return self.open_hour <= hour < self.close_hour
        return hour >= self.open_hour or hour < self.close_hour


class RecommendationResponse(BaseModel):
    """Response envelope. Serializes with the camelCase key the
    assignment specifies: {"restaurantRecommendation": [...]}."""

    model_config = ConfigDict(populate_by_name=True)

    restaurant_recommendation: list[Restaurant] = Field(
        alias="restaurantRecommendation", default_factory=list
    )
