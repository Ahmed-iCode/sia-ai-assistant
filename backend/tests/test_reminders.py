from datetime import datetime, timezone, timedelta
from fastapi import status
from app.services.reminder_service import ReminderService
from app.db.models import Reminder


def test_task_reminder_automatic_sync(client, auth_user, db_session):
    now = datetime.now(timezone.utc)
    start_time = now + timedelta(hours=3)
    end_time = start_time + timedelta(hours=1)

    # 1. Create task with 45m reminder
    res = client.post(
        "/api/v1/tasks",
        json={
            "title": "Task with Reminder",
            "startTime": start_time.isoformat(),
            "endTime": end_time.isoformat(),
            "remindBeforeMinutes": 45,
        },
        headers=auth_user["headers"],
    )
    assert res.status_code == status.HTTP_201_CREATED
    data = res.json()
    task_id = data["id"]
    assert len(data["reminders"]) == 1
    assert data["reminders"][0]["offsetMinutes"] == 45

    # 2. Update task start time and offset to 15m
    new_start = start_time + timedelta(hours=2)
    new_end = new_start + timedelta(hours=1)

    update_res = client.put(
        f"/api/v1/tasks/{task_id}",
        json={
            "startTime": new_start.isoformat(),
            "endTime": new_end.isoformat(),
            "remindBeforeMinutes": 15,
        },
        headers=auth_user["headers"],
    )
    assert update_res.status_code == status.HTTP_200_OK
    updated_data = update_res.json()
    assert len(updated_data["reminders"]) == 1
    assert updated_data["reminders"][0]["offsetMinutes"] == 15


def test_task_reminder_zero_offset(client, auth_user, db_session):
    now = datetime.now(timezone.utc)
    start_time = now + timedelta(minutes=1)
    end_time = start_time + timedelta(minutes=30)

    # Create task with 0m reminder (remind at event start time)
    res = client.post(
        "/api/v1/tasks",
        json={
            "title": "Drink Water in 1 Minute",
            "startTime": start_time.isoformat(),
            "endTime": end_time.isoformat(),
            "remindBeforeMinutes": 0,
        },
        headers=auth_user["headers"],
    )
    assert res.status_code == status.HTTP_201_CREATED
    data = res.json()
    assert len(data["reminders"]) == 1
    assert data["reminders"][0]["offsetMinutes"] == 0
    # remind_at should match start_time
    assert data["reminders"][0]["remindAt"] is not None


def test_get_upcoming_reminders(client, auth_user):
    now = datetime.now(timezone.utc)
    start_time = now + timedelta(hours=2)
    end_time = start_time + timedelta(hours=1)

    client.post(
        "/api/v1/tasks",
        json={
            "title": "Upcoming Reminder Task",
            "startTime": start_time.isoformat(),
            "endTime": end_time.isoformat(),
            "remindBeforeMinutes": 30,
        },
        headers=auth_user["headers"],
    )

    res = client.get("/api/v1/reminders/upcoming", headers=auth_user["headers"])
    assert res.status_code == status.HTTP_200_OK
    reminders = res.json()
    assert len(reminders) >= 1
    assert reminders[0]["offsetMinutes"] == 30


def test_reminder_scheduler_dispatch(client, auth_user, db_session):
    now = datetime.now(timezone.utc)
    # Create task whose reminder is in the past (due now)
    past_start = now + timedelta(minutes=10)
    past_end = past_start + timedelta(hours=1)

    client.post(
        "/api/v1/tasks",
        json={
            "title": "Past Due Reminder Task",
            "startTime": past_start.isoformat(),
            "endTime": past_end.isoformat(),
            "remindBeforeMinutes": 30,  # remind_at was 20 minutes ago!
        },
        headers=auth_user["headers"],
    )

    # Run reminder dispatcher
    dispatched = ReminderService.check_and_dispatch_due_reminders(db_session)
    assert dispatched >= 1

    # Check reminder marked as sent and triggered
    rem = db_session.query(Reminder).filter(Reminder.is_sent == True).first()
    assert rem is not None
    assert rem.is_triggered is True
    assert rem.sent_at is not None


def test_push_subscription(client, auth_user):
    payload = {
        "endpoint": "https://fcm.googleapis.com/fcm/send/test-device-token-1234",
        "keys": {"p256dh": "key123", "auth": "auth123"},
        "deviceType": "android",
    }
    res = client.post("/api/v1/reminders/push-subscribe", json=payload, headers=auth_user["headers"])
    assert res.status_code == status.HTTP_201_CREATED
    data = res.json()
    assert data["endpoint"] == payload["endpoint"]
    assert data["deviceType"] == "android"
