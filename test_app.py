import pytest

import app as app_module


@pytest.fixture
def client():
    app_module.app.config["TESTING"] = True
    original = [dict(item) for item in app_module.items]
    with app_module.app.test_client() as client:
        yield client
    app_module.items[:] = original


def test_health(client):
    resp = client.get("/health")
    assert resp.status_code == 200
    assert resp.get_json() == {"status": "healthy"}


def test_list_items(client):
    resp = client.get("/items")
    assert resp.status_code == 200
    assert len(resp.get_json()["items"]) == 2


def test_get_item(client):
    assert client.get("/items/1").get_json()["name"] == "item_one"


def test_get_unknown_item_returns_404(client):
    assert client.get("/items/999").status_code == 404


def test_create_item(client):
    resp = client.post("/items", json={"name": "item_three", "value": 300})
    assert resp.status_code == 201
    assert resp.get_json() == {"id": 3, "name": "item_three", "value": 300}
    assert client.get("/items/3").status_code == 200


def test_create_item_without_name_is_rejected(client):
    assert client.post("/items", json={"value": 1}).status_code == 400


def test_create_item_without_json_body_is_rejected(client):
    resp = client.post("/items", data="pas du json", content_type="text/plain")
    assert resp.status_code in (400, 415)
