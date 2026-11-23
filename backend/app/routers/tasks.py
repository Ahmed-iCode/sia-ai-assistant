import logging
from datetime import datetime, date, timedelta
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Query, status, File, UploadFile, Form
from sqlalchemy.orm import Session
from sqlalchemy import or_

from app.core.security import get_current_user
from app.db.database import get_db
from app.db.models import Task, User
from app.schemas.common import TaskStatus, TaskPriority
from app.schemas.task import (
    TaskCreate,
    TaskUpdate,
    TaskResponse,
    ConflictDetail,
    FileExtractionResponse,
    BatchTaskCreate,
    BatchTaskResponse,
    StopRecurrenceResponse,
)
from app.schemas.free_slot import FreeSlotResponse
from app.services.schedule_service import ScheduleService
from app.services.reminder_service import ReminderService
from app.services.recurrence_service import RecurrenceService
from app.ai.file_extractor import extract_schedule_from_file

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/tasks", tags=["Tasks"])

ALLOWED_EXTRACT_MIMES = {
    "image/jpeg",
    "image/png",
    "image/webp",
    "application/pdf",
}
MAX_EXTRACT_FILE_SIZE = 5 * 1024 * 1024  # 5 MB


@router.get("", response_model=List[TaskResponse])
def get_tasks(
    start_date: Optional[datetime] = None,
    end_date: Optional[datetime] = None,
    status: Optional[TaskStatus] = None,
    priority: Optional[TaskPriority] = None,
    search: Optional[str] = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    # Auto-refill rolling window occurrences for active recurring tasks
    try:
        RecurrenceService.ensure_rolling_occurrences(db=db, user_id=current_user.id)
    except Exception as e:
        logger.warning(f"Error ensuring rolling occurrences: {e}")

    query = db.query(Task).filter(Task.user_id == current_user.id)

    if start_date:
        query = query.filter(Task.end_time >= start_date)
    if end_date:
        query = query.filter(Task.start_time <= end_date)
    if status:
        query = query.filter(Task.status == status.value)
    if priority:
        query = query.filter(Task.priority == priority.value)
    if search:
        search_fmt = f"%{search.strip()}%"
        query = query.filter(
            or_(
                Task.title.ilike(search_fmt),
                Task.description.ilike(search_fmt),
            )
        )

    tasks = query.order_by(Task.start_time.asc()).all()
    return tasks


@router.post("", response_model=TaskResponse, status_code=status.HTTP_201_CREATED)
def create_task(
    task_in: TaskCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    # 1. Conflict Detection
    if not task_in.force:
        conflicts = ScheduleService.check_conflicts(
            db=db,
            user_id=current_user.id,
            start_time=task_in.start_time,
            end_time=task_in.end_time,
        )
        if conflicts:
            duration_minutes = max(
                15,
                int((task_in.end_time - task_in.start_time).total_seconds() / 60),
            )
            start_d = task_in.start_time.date()
            alt_slots = ScheduleService.calculate_free_slots(
                db=db,
                user=current_user,
                start_date=start_d,
                end_date=start_d + timedelta(days=2),
                min_duration_minutes=duration_minutes,
            )

            conflict_detail = ConflictDetail(
                conflicting_task=conflicts[0],
                proposed_task=task_in,
                alternative_free_slots=alt_slots[:3],
                message="Schedule conflict detected with an existing task",
            )
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=conflict_detail.model_dump(by_alias=True, mode="json"),
            )

    # 2. Persist Task (Recurring or Single)
    if task_in.recurrence_type and task_in.recurrence_type != "none":
        primary_task = RecurrenceService.create_recurring_series(
            db=db,
            user=current_user,
            task_in=task_in,
        )
        return primary_task

    days_str = ",".join(task_in.recurrence_days) if task_in.recurrence_days else None
    task = Task(
        user_id=current_user.id,
        title=task_in.title,
        description=task_in.description,
        start_time=task_in.start_time,
        end_time=task_in.end_time,
        priority=task_in.priority.value,
        status=task_in.status.value,
        is_voice_created=task_in.is_voice_created,
        tags=task_in.tags,
        recurrence_type="none",
        recurrence_days=days_str,
        recurrence_end_date=task_in.recurrence_end_date,
        recurrence_count=task_in.recurrence_count,
        recurrence_group_id=task_in.recurrence_group_id,
        is_recurrence_active=task_in.is_recurrence_active,
    )
    db.add(task)
    db.flush()

    # 3. Synchronize linked reminder
    offset = (
        task_in.remind_before_minutes
        if task_in.remind_before_minutes is not None
        else current_user.default_reminder_offset_minutes
    )
    if offset is not None and offset >= 0:
        ReminderService.sync_task_reminder(db=db, task=task, offset_minutes=offset)

    db.commit()
    db.refresh(task)
    return task


@router.get("/free-slots", response_model=List[FreeSlotResponse])
def get_free_slots(
    start_date: Optional[date] = None,
    end_date: Optional[date] = None,
    min_duration_minutes: int = Query(30, ge=5, le=480),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    today = date.today()
    s_date = start_date or today
    e_date = end_date or (s_date + timedelta(days=7))

    if e_date < s_date:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="end_date must be on or after start_date",
        )

    return ScheduleService.calculate_free_slots(
        db=db,
        user=current_user,
        start_date=s_date,
        end_date=e_date,
        min_duration_minutes=min_duration_minutes,
    )


@router.post("/extract-from-file", response_model=FileExtractionResponse)
async def extract_tasks_from_file(
    file: UploadFile = File(...),
    instruction: Optional[str] = Form(None),
    timezone: str = Form("Africa/Cairo"),
    current_user: User = Depends(get_current_user),
):
    raw_mime = (file.content_type or "").lower().split(";")[0].strip()
    content_type = raw_mime
    if content_type not in ALLOWED_EXTRACT_MIMES:
        fname = (file.filename or "").lower()
        if fname.endswith(".pdf"):
            content_type = "application/pdf"
        elif fname.endswith(".jpg") or fname.endswith(".jpeg"):
            content_type = "image/jpeg"
        elif fname.endswith(".png"):
            content_type = "image/png"
        elif fname.endswith(".webp"):
            content_type = "image/webp"

    if content_type not in ALLOWED_EXTRACT_MIMES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="نوع الملف غير مدعوم. الأنواع المدعومة: JPG, PNG, WEBP, PDF / Unsupported file type. Allowed: JPG, PNG, WEBP, PDF",
        )

    file_bytes = await file.read()
    if len(file_bytes) > MAX_EXTRACT_FILE_SIZE:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail="حجم الملف كبير جداً. الحد الأقصى المسموح به هو 5 ميجابايت / File is too large. Maximum size is 5 MB",
        )
    if len(file_bytes) == 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="الملف فارغ / The uploaded file is empty",
        )

    try:
        extraction_res = extract_schedule_from_file(
            file_bytes=file_bytes,
            mime_type=content_type,
            user=current_user,
            instruction=instruction,
            timezone_name=timezone or current_user.timezone or "Africa/Cairo",
        )
        return extraction_res
    except Exception as e:
        logger.error(f"Error in extract_tasks_from_file: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"حدث خطأ أثناء تحليل المستند: {str(e)} / Failed to extract tasks from file: {str(e)}",
        )


@router.post("/batch", response_model=BatchTaskResponse, status_code=status.HTTP_201_CREATED)
def create_batch_tasks(
    batch_in: BatchTaskCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if not batch_in.tasks:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="قائمة المهام فارغة / Tasks list cannot be empty",
        )
    if len(batch_in.tasks) > 50:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="الحد الأقصى للإضافة دفعة واحدة هو 50 مهمة / Maximum 50 tasks allowed per batch",
        )

    created_tasks: List[Task] = []
    try:
        for task_in in batch_in.tasks:
            task = Task(
                user_id=current_user.id,
                title=task_in.title,
                description=task_in.description,
                start_time=task_in.start_time,
                end_time=task_in.end_time,
                priority=task_in.priority.value,
                status=task_in.status.value,
                is_voice_created=task_in.is_voice_created,
                tags=task_in.tags,
            )
            db.add(task)
            db.flush()

            offset = (
                task_in.remind_before_minutes
                if task_in.remind_before_minutes is not None
                else current_user.default_reminder_offset_minutes
            )
            if offset is not None and offset >= 0:
                ReminderService.sync_task_reminder(db=db, task=task, offset_minutes=offset)

            created_tasks.append(task)

        db.commit()
        for t in created_tasks:
            db.refresh(t)

        return BatchTaskResponse(
            created_count=len(created_tasks),
            tasks=[TaskResponse.model_validate(t) for t in created_tasks],
        )
    except Exception as e:
        db.rollback()
        logger.error(f"Failed to save batch tasks: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"فشل حفظ مجموعة المهام: {str(e)} / Failed to save batch tasks: {str(e)}",
        )


@router.get("/{task_id}", response_model=TaskResponse)
def get_task_by_id(
    task_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    task = db.query(Task).filter(Task.id == task_id, Task.user_id == current_user.id).first()
    if not task:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Task not found")
    return task


@router.put("/{task_id}", response_model=TaskResponse)
def update_task(
    task_id: str,
    task_in: TaskUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    task = db.query(Task).filter(Task.id == task_id, Task.user_id == current_user.id).first()
    if not task:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Task not found")

    new_start = task_in.start_time or task.start_time
    new_end = task_in.end_time or task.end_time

    if new_end <= new_start:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="end_time must be strictly after start_time",
        )

    # Check conflicts if times are being updated
    if not task_in.force and (task_in.start_time is not None or task_in.end_time is not None):
        conflicts = ScheduleService.check_conflicts(
            db=db,
            user_id=current_user.id,
            start_time=new_start,
            end_time=new_end,
            exclude_task_id=task.id,
        )
        if conflicts:
            duration_minutes = max(15, int((new_end - new_start).total_seconds() / 60))
            alt_slots = ScheduleService.calculate_free_slots(
                db=db,
                user=current_user,
                start_date=new_start.date(),
                end_date=new_start.date() + timedelta(days=2),
                min_duration_minutes=duration_minutes,
            )
            conflict_detail = ConflictDetail(
                conflicting_task=conflicts[0],
                proposed_task=TaskCreate(
                    title=task_in.title or task.title,
                    description=task_in.description if task_in.description is not None else task.description,
                    start_time=new_start,
                    end_time=new_end,
                    priority=task_in.priority or TaskPriority(task.priority),
                    status=task_in.status or TaskStatus(task.status),
                ),
                alternative_free_slots=alt_slots[:3],
                message="Schedule conflict detected with an existing task",
            )
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=conflict_detail.model_dump(by_alias=True, mode="json"),
            )

    # Apply updates
    if task_in.title is not None:
        task.title = task_in.title
    if task_in.description is not None:
        task.description = task_in.description
    if task_in.start_time is not None:
        task.start_time = task_in.start_time
    if task_in.end_time is not None:
        task.end_time = task_in.end_time
    if task_in.priority is not None:
        task.priority = task_in.priority.value
    if task_in.status is not None:
        task.status = task_in.status.value
    if task_in.is_voice_created is not None:
        task.is_voice_created = task_in.is_voice_created
    if task_in.tags is not None:
        task.tags = task_in.tags
    if task_in.recurrence_type is not None:
        task.recurrence_type = task_in.recurrence_type
    if task_in.recurrence_days is not None:
        task.recurrence_days = ",".join(task_in.recurrence_days) if task_in.recurrence_days else None
    if task_in.recurrence_end_date is not None:
        task.recurrence_end_date = task_in.recurrence_end_date
    if task_in.recurrence_count is not None:
        task.recurrence_count = task_in.recurrence_count
    if task_in.is_recurrence_active is not None:
        task.is_recurrence_active = task_in.is_recurrence_active

    # Synchronize reminder if start_time or remind_before_minutes changed
    if task_in.remind_before_minutes is not None or task_in.start_time is not None:
        current_offset = (
            task_in.remind_before_minutes
            if task_in.remind_before_minutes is not None
            else (task.reminders[0].offset_minutes if task.reminders else current_user.default_reminder_offset_minutes)
        )
        ReminderService.sync_task_reminder(db=db, task=task, offset_minutes=current_offset)

    db.commit()
    db.refresh(task)
    return task


@router.patch("/{task_id}/toggle", response_model=TaskResponse)
def toggle_task(
    task_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    task = db.query(Task).filter(Task.id == task_id, Task.user_id == current_user.id).first()
    if not task:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Task not found")

    if task.status == TaskStatus.completed.value:
        task.status = TaskStatus.pending.value
    else:
        task.status = TaskStatus.completed.value
        # If completing a recurring task, ensure rolling window is topped up
        if task.recurrence_type != "none" and task.is_recurrence_active:
            try:
                RecurrenceService.ensure_rolling_occurrences(db=db, user_id=current_user.id)
            except Exception as e:
                logger.warning(f"Error topping up recurring tasks on toggle: {e}")

    db.commit()
    db.refresh(task)
    return task


@router.post("/recurrence/{group_id}/stop", response_model=StopRecurrenceResponse)
def stop_recurring_series_endpoint(
    group_id: str,
    delete_future: bool = Query(True),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = RecurrenceService.stop_recurrence_series(
        db=db,
        user_id=current_user.id,
        group_id=group_id,
        delete_future=delete_future,
    )
    return result


@router.delete("/{task_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_task(
    task_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    task = db.query(Task).filter(Task.id == task_id, Task.user_id == current_user.id).first()
    if not task:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Task not found")

    db.delete(task)
    db.commit()
    return None
