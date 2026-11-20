from fastapi import status


def test_get_settings(client, auth_user):
    response = client.get("/api/v1/settings", headers=auth_user["headers"])
    assert response.status_code == status.HTTP_200_OK
    data = response.json()
    assert data["language"] == "ar"
    assert data["themeMode"] == "dark"
    assert data["workingHoursStart"] == "09:00"
    assert data["workingHoursEnd"] == "22:00"
    assert data["defaultReminderOffsetMinutes"] == 30
    assert data["timezone"] == "Africa/Cairo"


def test_update_settings(client, auth_user):
    update_payload = {
        "language": "en",
        "themeMode": "light",
        "workingHoursStart": "10:00",
        "workingHoursEnd": "20:00",
        "defaultReminderOffsetMinutes": 15,
        "soundEnabled": False,
    }
    response = client.put("/api/v1/settings", json=update_payload, headers=auth_user["headers"])
    assert response.status_code == status.HTTP_200_OK
    data = response.json()
    assert data["language"] == "en"
    assert data["themeMode"] == "light"
    assert data["workingHoursStart"] == "10:00"
    assert data["workingHoursEnd"] == "20:00"
    assert data["defaultReminderOffsetMinutes"] == 15
    assert data["soundEnabled"] is False
