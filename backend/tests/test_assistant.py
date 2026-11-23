import io
from datetime import datetime, timedelta, timezone
from unittest.mock import MagicMock
import pytest
from fastapi import HTTPException

from app.db.models import Task, ChatMessage
from app.schemas.common import AiCardType, TaskPriority, TaskStatus, MessageSender
from app.ai.prompts import build_system_prompt
from app.ai.stt_service import transcribe_audio, MAX_AUDIO_SIZE_BYTES
from app.ai.tools import ToolExecutor, parse_datetime
from app.schemas.action_card import AiActionCardResponse


def test_system_prompt_builder(auth_user):
    user = auth_user["user"]
    prompt = build_system_prompt(user)
    assert user.name in prompt
    assert "Africa/Cairo" in prompt
    assert user.working_hours_start in prompt
    assert user.working_hours_end in prompt
    assert "BILINGUAL CAPABILITY" in prompt
    assert "create_task" in prompt
    assert "delete_task" in prompt
    assert "T4S" in prompt
    assert "Ahmed Samir" in prompt
    assert "أحمد سمير" in prompt
    assert "Sia" in prompt
    assert "NEVER write `سيا` in Arabic script" in prompt


def test_parse_datetime_helper():
    dt1 = parse_datetime("2026-11-25T14:30:00")
    assert dt1.year == 2026
    assert dt1.month == 11
    assert dt1.day == 25
    assert dt1.hour == 14
    assert dt1.minute == 30
    assert dt1.tzinfo is not None

    dt2 = parse_datetime("2026-11-25 15:00:00+02:00")
    assert dt2.hour == 15


def test_stt_validations():
    # Empty audio
    with pytest.raises(HTTPException) as exc_empty:
        transcribe_audio(b"", "audio.wav")
    assert exc_empty.value.status_code == 400

    # Oversized audio
    huge_bytes = b"0" * (MAX_AUDIO_SIZE_BYTES + 100)
    with pytest.raises(HTTPException) as exc_large:
        transcribe_audio(huge_bytes, "audio.wav")
    assert exc_large.value.status_code == 400

    # Unsupported extension
    with pytest.raises(HTTPException) as exc_ext:
        transcribe_audio(b"dummy audio content", "malicious.exe")
    assert exc_ext.value.status_code == 400


def test_stt_transcription_mock():
    mock_groq = MagicMock()
    mock_transcription = MagicMock()
    mock_transcription.text = "عندي ميتنج بكرة الساعة 3"
    mock_groq.audio.transcriptions.create.return_value = mock_transcription

    result = transcribe_audio(b"RIFF dummy wav data", "test.wav", client=mock_groq)
    assert result == "عندي ميتنج بكرة الساعة 3"
    assert mock_groq.audio.transcriptions.create.called


def test_tool_executor_create_task(db_session, auth_user):
    user = auth_user["user"]
    executor = ToolExecutor(db=db_session, user=user)

    res = executor.create_task(
        title="Sprint Review",
        start_time="2026-11-25T10:00:00+02:00",
        end_time="2026-11-25T11:00:00+02:00",
        priority="high",
        remind_before_minutes=15,
    )

    assert res["status"] == "success"
    assert executor.tasks_mutated is True
    assert executor.action_card is not None
    assert executor.action_card.type == AiCardType.taskCreated
    assert executor.action_card.task.title == "Sprint Review"
    assert executor.action_card.task.priority == TaskPriority.high

    # Check task exists in DB
    created_db = db_session.query(Task).filter(Task.title == "Sprint Review").first()
    assert created_db is not None
    assert len(created_db.reminders) == 1
    assert created_db.reminders[0].offset_minutes == 15


def test_tool_executor_conflict_alert(db_session, auth_user):
    user = auth_user["user"]
    executor = ToolExecutor(db=db_session, user=user)

    # 1. Create first task
    executor.create_task(
        title="Existing Team Standup",
        start_time="2026-11-25T10:00:00+02:00",
        end_time="2026-11-25T11:00:00+02:00",
    )

    # 2. Try creating overlapping task
    res_conflict = executor.create_task(
        title="Conflicting Client Call",
        start_time="2026-11-25T10:30:00+02:00",
        end_time="2026-11-25T11:30:00+02:00",
        force=False,
    )

    assert res_conflict["status"] == "conflict"
    assert "Conflicting Client Call" not in [t.title for t in db_session.query(Task).all()]
    assert executor.action_card is not None
    assert executor.action_card.type == AiCardType.conflictAlert
    assert executor.action_card.conflicting_task.title == "Existing Team Standup"
    assert len(executor.action_card.free_slots) > 0


def test_tool_executor_find_free_slots(db_session, auth_user):
    user = auth_user["user"]
    executor = ToolExecutor(db=db_session, user=user)

    res = executor.find_free_slots(date="2026-11-25", min_duration_minutes=30)
    assert res["count"] > 0
    assert executor.action_card is not None
    assert executor.action_card.type == AiCardType.freeSlots
    assert len(executor.action_card.free_slots) > 0


def test_tool_executor_delete_confirmation(db_session, auth_user):
    user = auth_user["user"]
    executor = ToolExecutor(db=db_session, user=user)

    # Create a task
    executor.create_task(
        title="Task to delete",
        start_time="2026-11-25T14:00:00+02:00",
        end_time="2026-11-25T15:00:00+02:00",
    )
    task = db_session.query(Task).filter(Task.title == "Task to delete").first()

    # Call delete without confirm
    res_unconfirmed = executor.delete_task(task_id=task.id, confirm=False)
    assert res_unconfirmed["status"] == "confirmation_required"
    assert executor.action_card is not None
    assert executor.action_card.type == AiCardType.deleteConfirm
    assert db_session.query(Task).filter(Task.id == task.id).first() is not None

    # Call delete with confirm
    res_confirmed = executor.delete_task(task_id=task.id, confirm=True)
    assert res_confirmed["status"] == "success"
    assert db_session.query(Task).filter(Task.id == task.id).first() is None


def test_tool_executor_multi_tenant_isolation(db_session, auth_user, other_user):
    user_a = auth_user["user"]
    user_b = other_user["user"]

    exec_a = ToolExecutor(db=db_session, user=user_a)
    exec_b = ToolExecutor(db=db_session, user=user_b)

    # User A creates a task
    exec_a.create_task(
        title="User A Secret Task",
        start_time="2026-11-25T10:00:00+02:00",
        end_time="2026-11-25T11:00:00+02:00",
    )
    task_a = db_session.query(Task).filter(Task.title == "User A Secret Task").first()

    # User B tries to delete User A's task
    del_attempt = exec_b.delete_task(task_id=task_a.id, confirm=True)
    assert del_attempt["status"] == "error"
    assert "not found" in del_attempt["message"].lower()

    # Task A still exists
    assert db_session.query(Task).filter(Task.id == task_a.id).first() is not None


def test_assistant_message_flow_mock(client, auth_user, monkeypatch):
    """
    Tests POST /api/v1/assistant/message end-to-end with mocked Gemini calling create_task tool.
    """
    user = auth_user["user"]

    # Mock Gemini response
    class MockCall:
        name = "create_task"
        args = {
            "title": "Design Meeting",
            "start_time": "2026-11-25T15:00:00+02:00",
            "end_time": "2026-11-25T16:00:00+02:00",
            "priority": "high",
        }

    class MockContent:
        parts = []

    class MockCandidate:
        content = MockContent()

    class MockResponseTurn1:
        function_calls = [MockCall()]
        candidates = [MockCandidate()]
        text = None

    class MockResponseTurn2:
        function_calls = None
        candidates = [MockCandidate()]
        text = "تمام، ضفتلك Design Meeting الساعة 3."

    responses = [MockResponseTurn1(), MockResponseTurn2()]
    call_count = 0

    def mock_call_gemini(client_arg, contents, config):
        nonlocal call_count
        resp = responses[call_count]
        call_count += 1
        return resp

    monkeypatch.setattr("app.ai.orchestrator._call_gemini", mock_call_gemini)

    payload = {"text": "ضفلي ميتنج ديزاين بكرة الساعة 3"}
    response = client.post(
        "/api/v1/assistant/message",
        json=payload,
        headers=auth_user["headers"],
    )

    assert response.status_code == 200
    data = response.json()

    assert data["tasksMutated"] is True
    assert data["assistantMessage"]["text"] == "تمام، ضفتلك Design Meeting الساعة 3."
    assert data["actionCard"] is not None
    assert data["actionCard"]["type"] == "taskCreated"
    assert data["actionCard"]["task"]["title"] == "Design Meeting"


def test_assistant_voice_endpoint_mock(client, auth_user, monkeypatch):
    """
    Tests POST /api/v1/assistant/voice end-to-end with mocked Groq Whisper and Gemini.
    """
    monkeypatch.setattr(
        "app.routers.assistant.transcribe_audio",
        lambda file_bytes, filename: "عندي ميتنج بكرة الساعة 2",
    )

    class MockResponse:
        function_calls = None
        candidates = []
        text = "أهلاً بيك! حاضر، مسجل."

    monkeypatch.setattr(
        "app.ai.orchestrator._call_gemini",
        lambda client_arg, contents, config: MockResponse(),
    )

    files = {"audio": ("test.wav", b"dummy_audio_bytes", "audio/wav")}
    response = client.post(
        "/api/v1/assistant/voice",
        files=files,
        data={"duration_seconds": 3},
        headers=auth_user["headers"],
    )

    assert response.status_code == 200
    data = response.json()
    assert data["transcript"] == "عندي ميتنج بكرة الساعة 2"
    assert data["assistantMessage"]["text"] == "أهلاً بيك! حاضر، مسجل."


def test_actions_confirm_delete_endpoint(client, auth_user, db_session):
    user = auth_user["user"]
    task = Task(
        user_id=user.id,
        title="Task to confirm delete",
        start_time=datetime.now(timezone.utc),
        end_time=datetime.now(timezone.utc) + timedelta(hours=1),
    )
    db_session.add(task)
    db_session.commit()
    db_session.refresh(task)

    response = client.post(
        f"/api/v1/assistant/actions/confirm-delete/{task.id}",
        headers=auth_user["headers"],
    )
    assert response.status_code == 200
    assert response.json()["success"] is True
    assert response.json()["tasksMutated"] is True

    # Assert deleted from DB
    assert db_session.query(Task).filter(Task.id == task.id).first() is None


def test_actions_undo_create_endpoint(client, auth_user, db_session):
    user = auth_user["user"]
    task = Task(
        user_id=user.id,
        title="Accidental Task",
        start_time=datetime.now(timezone.utc),
        end_time=datetime.now(timezone.utc) + timedelta(hours=1),
    )
    db_session.add(task)
    db_session.commit()
    db_session.refresh(task)

    response = client.post(
        f"/api/v1/assistant/actions/undo-create/{task.id}",
        headers=auth_user["headers"],
    )
    assert response.status_code == 200
    assert response.json()["success"] is True
    assert db_session.query(Task).filter(Task.id == task.id).first() is None


def test_actions_resolve_conflict_endpoint(client, auth_user, db_session):
    payload = {
        "task": {
            "title": "Resolved Task",
            "startTime": "2026-11-26T10:00:00+02:00",
            "endTime": "2026-11-26T11:00:00+02:00",
            "priority": "medium",
            "status": "pending",
        },
        "selectedSlot": {
            "start": "2026-11-26T14:00:00+02:00",
            "end": "2026-11-26T15:00:00+02:00",
            "durationMinutes": 60,
        },
        "force": False,
    }

    response = client.post(
        "/api/v1/assistant/actions/resolve-conflict",
        json=payload,
        headers=auth_user["headers"],
    )
    assert response.status_code == 200
    data = response.json()
    assert data["success"] is True
    assert data["task"]["title"] == "Resolved Task"
    assert "14:00:00" in data["task"]["startTime"]


def test_get_chat_history_endpoint(client, auth_user, db_session):
    user = auth_user["user"]
    now = datetime.now(timezone.utc)

    msg1 = ChatMessage(
        user_id=user.id,
        sender="user",
        text="Hello Assistant",
        timestamp=now,
    )
    msg2 = ChatMessage(
        user_id=user.id,
        sender="assistant",
        text="Hello! How can I help you?",
        action_card_data={"type": "freeSlots", "freeSlots": []},
        timestamp=now + timedelta(seconds=1),
    )
    db_session.add_all([msg1, msg2])
    db_session.commit()

    response = client.get(
        "/api/v1/assistant/history",
        headers=auth_user["headers"],
    )
    assert response.status_code == 200
    data = response.json()
    assert len(data) == 2
    assert data[0]["text"] == "Hello Assistant"
    assert data[0]["sender"] == "user"
    assert data[1]["text"] == "Hello! How can I help you?"
    assert data[1]["sender"] == "assistant"
    assert data[1]["actionCard"]["type"] == "freeSlots"
