from datetime import datetime, timezone, timedelta
from fastapi import status


def test_create_task_success(client, auth_user):
    now = datetime.now(timezone.utc)
    start_time = now + timedelta(hours=2)
    end_time = start_time + timedelta(hours=1)

    payload = {
        "title": "مراجعة كود الواجهات",
        "description": "فحص التجاوب ودعم اللغة العربية",
        "startTime": start_time.isoformat(),
        "endTime": end_time.isoformat(),
        "priority": "high",
        "status": "pending",
        "remindBeforeMinutes": 30,
        "isVoiceCreated": False,
        "tags": ["frontend", "arabic"],
    }
    response = client.post("/api/v1/tasks", json=payload, headers=auth_user["headers"])
    assert response.status_code == status.HTTP_201_CREATED
    data = response.json()
    assert data["title"] == "مراجعة كود الواجهات"
    assert data["priority"] == "high"
    assert data["status"] == "pending"
    assert len(data["reminders"]) == 1
    assert data["reminders"][0]["offsetMinutes"] == 30


def test_create_task_invalid_time_order(client, auth_user):
    now = datetime.now(timezone.utc)
    start_time = now + timedelta(hours=3)
    end_time = now + timedelta(hours=2)  # end_time before start_time!

    payload = {
        "title": "Invalid Task",
        "startTime": start_time.isoformat(),
        "endTime": end_time.isoformat(),
    }
    response = client.post("/api/v1/tasks", json=payload, headers=auth_user["headers"])
    assert response.status_code == status.HTTP_422_UNPROCESSABLE_ENTITY


def test_get_tasks_filtering_and_search(client, auth_user):
    now = datetime.now(timezone.utc)
    t1_start = now + timedelta(hours=1)
    t1_end = t1_start + timedelta(hours=1)

    t2_start = now + timedelta(hours=4)
    t2_end = t2_start + timedelta(hours=1)

    client.post(
        "/api/v1/tasks",
        json={
            "title": "Frontend Review",
            "startTime": t1_start.isoformat(),
            "endTime": t1_end.isoformat(),
            "priority": "urgent",
            "status": "pending",
        },
        headers=auth_user["headers"],
    )

    client.post(
        "/api/v1/tasks",
        json={
            "title": "Backend Optimization",
            "startTime": t2_start.isoformat(),
            "endTime": t2_end.isoformat(),
            "priority": "low",
            "status": "completed",
        },
        headers=auth_user["headers"],
    )

    # Filter by search
    res = client.get("/api/v1/tasks?search=frontend", headers=auth_user["headers"])
    assert res.status_code == status.HTTP_200_OK
    assert len(res.json()) == 1
    assert res.json()[0]["title"] == "Frontend Review"

    # Filter by priority
    res = client.get("/api/v1/tasks?priority=urgent", headers=auth_user["headers"])
    assert res.status_code == status.HTTP_200_OK
    assert len(res.json()) == 1
    assert res.json()[0]["priority"] == "urgent"

    # Filter by status
    res = client.get("/api/v1/tasks?status=completed", headers=auth_user["headers"])
    assert res.status_code == status.HTTP_200_OK
    assert len(res.json()) == 1
    assert res.json()[0]["status"] == "completed"


def test_toggle_task_completion(client, auth_user):
    now = datetime.now(timezone.utc)
    start_time = now + timedelta(hours=2)
    end_time = start_time + timedelta(hours=1)

    create_res = client.post(
        "/api/v1/tasks",
        json={
            "title": "Toggle Task",
            "startTime": start_time.isoformat(),
            "endTime": end_time.isoformat(),
            "status": "pending",
        },
        headers=auth_user["headers"],
    )
    task_id = create_res.json()["id"]

    # Toggle to completed
    res = client.patch(f"/api/v1/tasks/{task_id}/toggle", headers=auth_user["headers"])
    assert res.status_code == status.HTTP_200_OK
    assert res.json()["status"] == "completed"

    # Toggle back to pending
    res = client.patch(f"/api/v1/tasks/{task_id}/toggle", headers=auth_user["headers"])
    assert res.status_code == status.HTTP_200_OK
    assert res.json()["status"] == "pending"


def test_delete_task_cascades_reminders(client, auth_user, db_session):
    now = datetime.now(timezone.utc)
    start_time = now + timedelta(hours=2)
    end_time = start_time + timedelta(hours=1)

    create_res = client.post(
        "/api/v1/tasks",
        json={
            "title": "Delete Me",
            "startTime": start_time.isoformat(),
            "endTime": end_time.isoformat(),
            "remindBeforeMinutes": 30,
        },
        headers=auth_user["headers"],
    )
    task_id = create_res.json()["id"]

    # Delete task
    res = client.delete(f"/api/v1/tasks/{task_id}", headers=auth_user["headers"])
    assert res.status_code == status.HTTP_204_NO_CONTENT

    # Verify task is gone
    get_res = client.get(f"/api/v1/tasks/{task_id}", headers=auth_user["headers"])
    assert get_res.status_code == status.HTTP_404_NOT_FOUND


def test_multi_tenant_isolation(client, auth_user, other_user):
    """User B must not be able to view, edit, or delete User A's task."""
    now = datetime.now(timezone.utc)
    start_time = now + timedelta(hours=2)
    end_time = start_time + timedelta(hours=1)

    # User A creates a task
    create_res = client.post(
        "/api/v1/tasks",
        json={
            "title": "User A Secret Task",
            "startTime": start_time.isoformat(),
            "endTime": end_time.isoformat(),
        },
        headers=auth_user["headers"],
    )
    task_id = create_res.json()["id"]

    # User B attempts to access it -> 404
    res = client.get(f"/api/v1/tasks/{task_id}", headers=other_user["headers"])
    assert res.status_code == status.HTTP_404_NOT_FOUND

    # User B attempts to delete it -> 404
    res = client.delete(f"/api/v1/tasks/{task_id}", headers=other_user["headers"])
    assert res.status_code == status.HTTP_404_NOT_FOUND

    # User B's task list does not include User A's task
    res = client.get("/api/v1/tasks", headers=other_user["headers"])
    assert res.status_code == status.HTTP_200_OK
    assert len(res.json()) == 0
