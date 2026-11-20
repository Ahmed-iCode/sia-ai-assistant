from datetime import datetime, timezone, timedelta, date
from fastapi import status


def test_conflict_detection_and_alternative_slots(client, auth_user):
    # Fixed base date for predictable testing
    base_date = datetime(2026, 11, 25, 13, 0, 0, tzinfo=timezone.utc)

    # 1. Create baseline task from 13:00 to 14:00
    baseline_payload = {
        "title": "اجتماع فريق التطوير والذكاء الاصطناعي",
        "startTime": base_date.isoformat(),
        "endTime": (base_date + timedelta(hours=1)).isoformat(),
        "priority": "high",
    }
    create_res = client.post("/api/v1/tasks", json=baseline_payload, headers=auth_user["headers"])
    assert create_res.status_code == status.HTTP_201_CREATED

    # 2. Attempt to schedule overlapping task from 13:30 to 14:30 without force
    overlapping_start = base_date + timedelta(minutes=30)
    overlapping_end = overlapping_start + timedelta(hours=1)

    conflict_payload = {
        "title": "مراجعة تصميم التطبيق",
        "startTime": overlapping_start.isoformat(),
        "endTime": overlapping_end.isoformat(),
        "force": False,
    }
    conflict_res = client.post("/api/v1/tasks", json=conflict_payload, headers=auth_user["headers"])
    assert conflict_res.status_code == status.HTTP_409_CONFLICT
    error_data = conflict_res.json()["detail"]

    # Verify conflict detail format matches Flutter expected fields
    assert "conflictingTask" in error_data
    assert error_data["conflictingTask"]["title"] == "اجتماع فريق التطوير والذكاء الاصطناعي"
    assert "alternativeFreeSlots" in error_data
    assert isinstance(error_data["alternativeFreeSlots"], list)

    # 3. Create same task with force=True -> Bypasses conflict check
    forced_payload = {**conflict_payload, "force": True}
    forced_res = client.post("/api/v1/tasks", json=forced_payload, headers=auth_user["headers"])
    assert forced_res.status_code == status.HTTP_201_CREATED


def test_free_slots_calculation_within_working_hours(client, auth_user):
    # Query free slots for a test date window
    test_date = date(2026, 11, 26)
    res = client.get(
        f"/api/v1/tasks/free-slots?start_date={test_date.isoformat()}&end_date={test_date.isoformat()}&min_duration_minutes=45",
        headers=auth_user["headers"],
    )
    assert res.status_code == status.HTTP_200_OK
    slots = res.json()
    assert isinstance(slots, list)
    assert len(slots) > 0

    # Ensure all slots have start, end, and durationMinutes >= 45
    for slot in slots:
        assert "start" in slot
        assert "end" in slot
        assert "durationMinutes" in slot
        assert slot["durationMinutes"] >= 45
