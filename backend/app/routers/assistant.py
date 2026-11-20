import logging
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File, Form, Query
from sqlalchemy.orm import Session

from app.db.database import get_db
from app.db.models import User, Task, ChatMessage
from app.core.security import get_current_user
from app.schemas.action_card import (
    AssistantMessageRequest,
    AssistantResponse,
    ChatMessageResponse,
    AiActionCardResponse,
    ResolveConflictRequest,
)
from app.schemas.task import TaskResponse
from app.schemas.common import TaskStatus, TaskPriority
from app.services.schedule_service import ScheduleService
from app.services.reminder_service import ReminderService
from app.ai.stt_service import transcribe_audio
from app.ai.orchestrator import AgentOrchestrator

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/assistant", tags=["AI Assistant"])


@router.post("/message", response_model=AssistantResponse)
def send_text_message(
    request: AssistantMessageRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Sends a text message to the AI Task Assistant.
    Executes function tools and returns conversational response + structured action cards.
    """
    orchestrator = AgentOrchestrator(db=db, user=current_user)
    return orchestrator.process_message(text=request.text, is_voice=False)


@router.post("/voice", response_model=AssistantResponse)
async def send_voice_message(
    audio: UploadFile = File(...),
    duration_seconds: Optional[int] = Form(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Uploads an audio recording, transcribes via Groq Whisper, and processes with AI Assistant.
    """
    file_bytes = await audio.read()
    if not file_bytes:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Uploaded audio file is empty.",
        )

    transcript = transcribe_audio(
        file_bytes=file_bytes,
        filename=audio.filename or "recording.wav",
    )

    orchestrator = AgentOrchestrator(db=db, user=current_user)
    return orchestrator.process_message(
        text=transcript,
        is_voice=True,
        audio_duration_seconds=duration_seconds,
        transcript=transcript,
    )


@router.post("/actions/confirm-delete/{task_id}")
def confirm_delete_task(
    task_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Confirms and executes task deletion triggered from a DeleteConfirm card.
    """
    task = db.query(Task).filter(Task.id == task_id, Task.user_id == current_user.id).first()
    if not task:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Task not found.",
        )

    db.delete(task)
    db.commit()

    return {
        "success": True,
        "deletedTaskId": task_id,
        "tasksMutated": True,
    }


@router.post("/actions/undo-create/{task_id}")
def undo_create_task(
    task_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Undoes a task creation directly from a TaskCreated card.
    """
    task = db.query(Task).filter(Task.id == task_id, Task.user_id == current_user.id).first()
    if not task:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Task not found or already deleted.",
        )

    db.delete(task)
    db.commit()

    return {
        "success": True,
        "message": "Task creation undone successfully.",
        "tasksMutated": True,
    }


@router.post("/actions/resolve-conflict")
def resolve_conflict(
    request: ResolveConflictRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Resolves a schedule conflict by either applying a chosen free slot or forcing the schedule.
    """
    proposed = request.task
    start_time = proposed.start_time
    end_time = proposed.end_time

    # If user selected an alternative free slot
    if request.selected_slot:
        start_time = request.selected_slot.start
        end_time = request.selected_slot.end

    if not request.force and not request.selected_slot:
        conflicts = ScheduleService.check_conflicts(
            db=db,
            user_id=current_user.id,
            start_time=start_time,
            end_time=end_time,
        )
        if conflicts:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Schedule conflict still exists. Select an alternative slot or set force=True.",
            )

    task = Task(
        user_id=current_user.id,
        title=proposed.title,
        description=proposed.description,
        start_time=start_time,
        end_time=end_time,
        priority=proposed.priority.value,
        status=proposed.status.value,
        is_voice_created=proposed.is_voice_created,
        tags=proposed.tags,
    )
    db.add(task)
    db.flush()

    offset = proposed.remind_before_minutes or current_user.default_reminder_offset_minutes
    if offset and offset > 0:
        ReminderService.sync_task_reminder(db, task, offset_minutes=offset)

    db.commit()
    db.refresh(task)

    return {
        "success": True,
        "task": TaskResponse.model_validate(task),
        "tasksMutated": True,
    }


@router.get("/history", response_model=List[ChatMessageResponse])
def get_chat_history(
    limit: int = Query(50, ge=1, le=100),
    offset: int = Query(0, ge=0),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Returns persistent chat history for the authenticated user,
    including any associated structured action cards.
    """
    messages = (
        db.query(ChatMessage)
        .filter(ChatMessage.user_id == current_user.id)
        .order_by(ChatMessage.timestamp.asc())
        .offset(offset)
        .limit(limit)
        .all()
    )

    result: List[ChatMessageResponse] = []
    for msg in messages:
        card: Optional[AiActionCardResponse] = None
        if msg.action_card_data:
            try:
                card = AiActionCardResponse.model_validate(msg.action_card_data)
            except Exception as e:
                logger.warning(f"Could not parse action card for message {msg.id}: {e}")

        result.append(
            ChatMessageResponse(
                id=msg.id,
                sender=msg.sender,
                text=msg.text,
                timestamp=msg.timestamp,
                is_voice=msg.is_voice,
                audio_duration_seconds=msg.audio_duration_seconds,
                action_card=card,
            )
        )

    return result
