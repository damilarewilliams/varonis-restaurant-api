"""Business-logic tests — pure functions, no HTTP, no AWS."""

from app.models.restaurant import Restaurant
from app.services.recommendation import recommend


def make(name="R", style="Italian", vegetarian=False, open_hour=9, close_hour=22):
    return Restaurant(
        id=f"id-{name}", name=name, style=style, address="addr",
        vegetarian=vegetarian, open_hour=open_hour, close_hour=close_hour,
    )


def test_style_is_case_insensitive():
    catalog = [make(style="Italian"), make(name="K", style="Korean")]
    assert len(recommend(catalog, style="iTaLiAn")) == 1


def test_vegetarian_tristate():
    catalog = [make(vegetarian=True), make(name="B", vegetarian=False)]
    assert len(recommend(catalog, vegetarian=None)) == 2
    assert len(recommend(catalog, vegetarian=True)) == 1
    assert len(recommend(catalog, vegetarian=False)) == 1


def test_open_now_normal_hours():
    catalog = [make(open_hour=9, close_hour=17)]
    assert recommend(catalog, open_now=True, at_hour=12)
    assert not recommend(catalog, open_now=True, at_hour=18)
    assert recommend(catalog, open_now=True, at_hour=9)      # inclusive open
    assert not recommend(catalog, open_now=True, at_hour=17)  # exclusive close


def test_open_now_overnight_hours():
    catalog = [make(open_hour=22, close_hour=6)]
    assert recommend(catalog, open_now=True, at_hour=23)
    assert recommend(catalog, open_now=True, at_hour=3)
    assert not recommend(catalog, open_now=True, at_hour=12)


def test_open_24h_when_hours_equal():
    catalog = [make(open_hour=0, close_hour=0)]
    assert recommend(catalog, open_now=True, at_hour=4)


def test_no_matches_returns_empty_list():
    assert recommend([make(style="Italian")], style="Sushi") == []
