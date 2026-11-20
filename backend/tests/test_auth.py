from fastapi import status


def test_register_success(client):
    payload = {
        "name": "Sarah Connor",
        "email": "sarah@example.com",
        "password": "strongpassword123",
    }
    response = client.post("/api/v1/auth/register", json=payload)
    assert response.status_code == status.HTTP_201_CREATED
    data = response.json()
    assert "accessToken" in data or "access_token" in data
    assert data.get("tokenType", data.get("token_type")) == "bearer"


def test_register_duplicate_email(client, auth_user):
    payload = {
        "name": "Duplicate User",
        "email": "ahmed@example.com",  # Already exists from fixture
        "password": "password123",
    }
    response = client.post("/api/v1/auth/register", json=payload)
    assert response.status_code == status.HTTP_400_BAD_REQUEST
    assert "already exists" in response.json()["detail"]


def test_login_success(client, auth_user):
    payload = {
        "email": "ahmed@example.com",
        "password": "password123",
    }
    response = client.post("/api/v1/auth/login", json=payload)
    assert response.status_code == status.HTTP_200_OK
    data = response.json()
    assert "accessToken" in data or "access_token" in data


def test_login_invalid_password(client, auth_user):
    payload = {
        "email": "ahmed@example.com",
        "password": "wrongpassword",
    }
    response = client.post("/api/v1/auth/login", json=payload)
    assert response.status_code == status.HTTP_401_UNAUTHORIZED


def test_get_me_authenticated(client, auth_user):
    response = client.get("/api/v1/auth/me", headers=auth_user["headers"])
    assert response.status_code == status.HTTP_200_OK
    data = response.json()
    assert data["email"] == "ahmed@example.com"
    assert data["name"] == "Ahmed Mahmoud"
    assert data["settings"]["timezone"] == "Africa/Cairo"
    assert data["settings"]["workingHoursStart"] == "09:00"
    assert data["settings"]["workingHoursEnd"] == "22:00"


def test_get_me_unauthorized(client):
    response = client.get("/api/v1/auth/me")
    assert response.status_code == status.HTTP_401_UNAUTHORIZED
