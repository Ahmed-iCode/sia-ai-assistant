import io
import json
import pytest
from datetime import datetime, timezone, timedelta
from fastapi import status

from app.schemas.common import TaskPriority


def test_extract_schedule_from_image_mock(client, auth_user, monkeypatch):
    """
    Valid image extraction returns structured preview tasks with UTC Z timestamps.
    """
    mock_gemini_json = {
        "reply": "استخرجت لك ميعادين من صورة الجدول! تفقدها واضغط تأكيد لحفظها.",
        "extracted_tasks": [
            {
                "title": "محاضرة نظم التشغيل",
                "description": "قاعة 302",
                "start_time": "2026-11-26T08:00:00Z",
                "end_time": "2026-11-26T10:00:00Z",
                "priority": "high",
                "category": "Study",
                "reminder_minutes": 15,
            },
            {
                "title": "سكشن الخوارزميات",
                "description": "معمل 4",
                "start_time": "2026-11-26T10:30:00Z",
                "end_time": "2026-11-26T12:00:00Z",
                "priority": "medium",
                "category": "Study",
                "reminder_minutes": 15,
            },
        ],
    }

    class MockResponse:
        text = json.dumps(mock_gemini_json)

    def mock_call_gemini(client, contents, config):
        return MockResponse()

    monkeypatch.setattr("app.ai.file_extractor._call_gemini", mock_call_gemini)

    fake_image_bytes = b"\x89PNG\r\n\x1a\n" + b"\x00" * 200
    files = {"file": ("schedule.png", fake_image_bytes, "image/png")}
    data = {"instruction": "استخرج مواعيد المحاضرات", "timezone": "Africa/Cairo"}

    response = client.post(
        "/api/v1/tasks/extract-from-file",
        files=files,
        data=data,
        headers=auth_user["headers"],
    )

    assert response.status_code == status.HTTP_200_OK
    res_data = response.json()
    assert "reply" in res_data
    assert "استخرجت لك" in res_data["reply"]
    assert "extractedTasks" in res_data
    assert len(res_data["extractedTasks"]) == 2

    task1 = res_data["extractedTasks"][0]
    assert task1["title"] == "محاضرة نظم التشغيل"
    assert task1["startTime"].endswith("Z")
    assert task1["endTime"].endswith("Z")
    assert task1["priority"] == "high"
    assert task1["reminderMinutes"] == 15


def test_extract_schedule_from_pdf_mock(client, auth_user, monkeypatch):
    """
    Valid PDF extraction returns structured preview tasks.
    """
    mock_gemini_json = {
        "reply": "Here are the extracted appointments from your document.",
        "extracted_tasks": [
            {
                "title": "Dental Clinic Appointment",
                "description": "Dr. Sarah - Routine Checkup",
                "start_time": "2026-11-28T14:00:00Z",
                "end_time": "2026-11-28T15:00:00Z",
                "priority": "urgent",
                "category": "Health",
                "reminder_minutes": 30,
            }
        ],
    }

    class MockResponse:
        text = json.dumps(mock_gemini_json)

    def mock_call_gemini(client, contents, config):
        return MockResponse()

    monkeypatch.setattr("app.ai.file_extractor._call_gemini", mock_call_gemini)

    fake_pdf_bytes = b"%PDF-1.4\n" + b"\x00" * 300
    files = {"file": ("appointment.pdf", fake_pdf_bytes, "application/pdf")}

    response = client.post(
        "/api/v1/tasks/extract-from-file",
        files=files,
        headers=auth_user["headers"],
    )

    assert response.status_code == status.HTTP_200_OK
    res_data = response.json()
    assert len(res_data["extractedTasks"]) == 1
    assert res_data["extractedTasks"][0]["title"] == "Dental Clinic Appointment"
    assert res_data["extractedTasks"][0]["priority"] == "urgent"


def test_extract_schedule_unsupported_mime(client, auth_user):
    """
    Unsupported MIME type (e.g. text/plain or executable) returns 400.
    """
    files = {"file": ("script.py", b"print('hello')", "text/x-python")}
    response = client.post(
        "/api/v1/tasks/extract-from-file",
        files=files,
        headers=auth_user["headers"],
    )
    assert response.status_code == status.HTTP_400_BAD_REQUEST
    assert "غير مدعوم" in response.json()["detail"] or "Unsupported" in response.json()["detail"]


def test_extract_schedule_oversized_file(client, auth_user):
    """
    Oversized file (>5MB) returns 413 Request Entity Too Large.
    """
    huge_bytes = b"\x00" * (5 * 1024 * 1024 + 1024)  # 5 MB + 1 KB
    files = {"file": ("huge.jpg", huge_bytes, "image/jpeg")}
    response = client.post(
        "/api/v1/tasks/extract-from-file",
        files=files,
        headers=auth_user["headers"],
    )
    assert response.status_code == status.HTTP_413_REQUEST_ENTITY_TOO_LARGE
    assert "كبير جداً" in response.json()["detail"] or "too large" in response.json()["detail"]


def test_batch_create_tasks_success(client, auth_user):
    """
    POST /api/v1/tasks/batch creates multiple tasks atomically and returns TaskResponses.
    """
    base_time = datetime(2026, 12, 1, 9, 0, 0, tzinfo=timezone.utc)
    payload = {
        "tasks": [
            {
                "title": "مهمة مجمعة 1",
                "description": "وصف 1",
                "startTime": base_time.isoformat(),
                "endTime": (base_time + timedelta(hours=1)).isoformat(),
                "priority": "high",
                "remindBeforeMinutes": 15,
            },
            {
                "title": "مهمة مجمعة 2",
                "description": "وصف 2",
                "startTime": (base_time + timedelta(hours=2)).isoformat(),
                "endTime": (base_time + timedelta(hours=3)).isoformat(),
                "priority": "medium",
                "remindBeforeMinutes": 30,
            },
        ]
    }

    response = client.post(
        "/api/v1/tasks/batch",
        json=payload,
        headers=auth_user["headers"],
    )

    assert response.status_code == status.HTTP_201_CREATED
    res_data = response.json()
    assert res_data["createdCount"] == 2
    assert len(res_data["tasks"]) == 2

    t1 = res_data["tasks"][0]
    assert t1["title"] == "مهمة مجمعة 1"
    assert t1["priority"] == "high"
    assert t1["startTime"].endswith("Z")
    assert len(t1["reminders"]) == 1
    assert t1["reminders"][0]["offsetMinutes"] == 15

    t2 = res_data["tasks"][1]
    assert t2["title"] == "مهمة مجمعة 2"
    assert t2["priority"] == "medium"
    assert t2["startTime"].endswith("Z")
    assert len(t2["reminders"]) == 1
    assert t2["reminders"][0]["offsetMinutes"] == 30


def test_batch_create_tasks_empty_fails(client, auth_user):
    """
    Empty task list rejected by validation.
    """
    response = client.post(
        "/api/v1/tasks/batch",
        json={"tasks": []},
        headers=auth_user["headers"],
    )
    assert response.status_code in [status.HTTP_400_BAD_REQUEST, status.HTTP_422_UNPROCESSABLE_ENTITY]
