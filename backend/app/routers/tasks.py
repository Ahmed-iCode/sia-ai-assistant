from datetime import datetime, date, timedelta
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session
from sqlalchemy import or_

from app.core.security import get_current_user
from app.db.database import get_db
from app.db.models import Task, User
from app.schemas.common import TaskStatus, TaskPriority
from app.schemas.task import TaskCreate, TaskUpdate, TaskResponse, ConflictDetail
from app.schemas.free_slot import FreeSlotResponse
from app.services.schedule_service import ScheduleService
from app.services.reminder_service import ReminderService

router = APIRouter(prefix="/tasks", tags=["Tasks"])


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

    # 2. Persist Task
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

    # 3. Synchronize linked reminder
    offset = (
        task_in.remind_before_minutes
        if task_in.remind_before_minutes is not None
        else current_user.default_reminder_offset_minutes
    )
    if offset and offset > 0:
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

    db.commit()
    db.refresh(task)
    return task


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
