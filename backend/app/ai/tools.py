import logging
from datetime import datetime, date, timedelta, time
from typing import Optional, List, Dict, Any
from zoneinfo import ZoneInfo
from sqlalchemy.orm import Session
from sqlalchemy import or_

from app.db.models import Task, User
from app.schemas.common import AiCardType, TaskPriority, TaskStatus
from app.schemas.task import TaskResponse, TaskCreate
from app.schemas.free_slot import FreeSlotResponse
from app.schemas.action_card import AiActionCardResponse
from app.services.schedule_service import ScheduleService, ensure_aware
from app.services.reminder_service import ReminderService
from app.services.recurrence_service import RecurrenceService

logger = logging.getLogger(__name__)


def parse_datetime(dt_str: str, tz_name: str = "Africa/Cairo") -> datetime:
    """
    Parses datetime string supporting ISO 8601 with or without timezone offset.
    If offset is missing, localizes to tz_name.
    """
    try:
        user_tz = ZoneInfo(tz_name)
    except Exception:
        user_tz = ZoneInfo("Africa/Cairo")

    # Clean string
    cleaned = dt_str.strip().replace("Z", "+00:00")
    if " " in cleaned and "T" not in cleaned:
        cleaned = cleaned.replace(" ", "T")

    try:
        dt = datetime.fromisoformat(cleaned)
    except Exception:
        # Fallback for simple date YYYY-MM-DD
        try:
            d = date.fromisoformat(cleaned[:10])
            dt = datetime.combine(d, time(9, 0))
        except Exception as e:
            raise ValueError(f"Could not parse datetime string '{dt_str}': {e}")

    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=user_tz)
    return dt


class ToolExecutor:
    """
    Executes tool calls from Gemini securely scoped to the authenticated user.
    Tracks mutated tasks and produces structured Action Cards (AiActionCardResponse).
    """

    def __init__(self, db: Session, user: User, is_voice: bool = False):
        self.db = db
        self.user = user
        self.is_voice = is_voice
        self.tasks_mutated: bool = False
        self.action_card: Optional[AiActionCardResponse] = None

    def create_task(
        self,
        title: str,
        start_time: str,
        end_time: str,
        description: Optional[str] = None,
        priority: str = "medium",
        remind_before_minutes: Optional[int] = 30,
        force: bool = False,
        recurrence_type: str = "none",
        recurrence_days: Optional[List[str]] = None,
        recurrence_end_date: Optional[str] = None,
        recurrence_count: Optional[int] = None,
    ) -> Dict[str, Any]:
        """
        Creates a new task in user's calendar. Supports recurring tasks.
        Checks for schedule conflicts unless force is True.
        """
        tz_name = self.user.timezone or "Africa/Cairo"
        dt_start = parse_datetime(start_time, tz_name)
        dt_end = parse_datetime(end_time, tz_name)

        if dt_end <= dt_start:
            dt_end = dt_start + timedelta(minutes=30)

        # Validate priority enum
        try:
            p_enum = TaskPriority(priority.lower())
        except Exception:
            p_enum = TaskPriority.medium

        # Handle recurring task creation
        rec_type = (recurrence_type or "none").lower()
        if rec_type != "none":
            rec_end_dt: Optional[datetime] = None
            if recurrence_end_date:
                try:
                    rec_end_dt = parse_datetime(recurrence_end_date, tz_name)
                except Exception:
                    rec_end_dt = None

            rec_offset = remind_before_minutes
            if rec_offset is not None and rec_offset > 0:
                user_tz = ZoneInfo(tz_name)
                now_user = datetime.now(user_tz)
                if dt_start - timedelta(minutes=rec_offset) <= now_user and dt_start > now_user:
                    rec_offset = 0

            task_in = TaskCreate(
                title=title,
                description=description,
                start_time=dt_start,
                end_time=dt_end,
                priority=p_enum,
                status=TaskStatus.pending,
                remind_before_minutes=rec_offset,
                is_voice_created=self.is_voice,
                tags=[],
                recurrence_type=rec_type,
                recurrence_days=recurrence_days or [],
                recurrence_end_date=rec_end_dt,
                recurrence_count=recurrence_count,
                force=force,
            )

            primary_task = RecurrenceService.create_recurring_series(
                db=self.db,
                user=self.user,
                task_in=task_in,
            )

            task_response = TaskResponse.model_validate(primary_task)
            self.tasks_mutated = True
            self.action_card = AiActionCardResponse(
                type=AiCardType.taskCreated,
                task=task_response,
                message=f"Recurring task created successfully ({rec_type})",
            )

            return {
                "status": "success",
                "message": f"Recurring task '{primary_task.title}' created successfully ({rec_type}).",
                "task": task_response.model_dump(mode="json", by_alias=True),
            }

        # Conflict check
        conflicts = ScheduleService.check_conflicts(
            db=self.db,
            user_id=self.user.id,
            start_time=dt_start,
            end_time=dt_end,
        )

        if conflicts and not force:
            conflicting_task = conflicts[0]
            # Calculate alternative free slots
            alt_slots = ScheduleService.calculate_free_slots(
                db=self.db,
                user=self.user,
                start_date=dt_start.date(),
                end_date=dt_start.date() + timedelta(days=1),
                min_duration_minutes=int((dt_end - dt_start).total_seconds() / 60),
            )

            # Build dummy TaskResponse for the proposed task
            proposed_response = TaskResponse(
                id="proposed-new-task",
                title=title,
                description=description,
                start_time=dt_start,
                end_time=dt_end,
                priority=p_enum,
                status=TaskStatus.pending,
                is_voice_created=self.is_voice,
                tags=[],
                created_at=datetime.now(ZoneInfo("UTC")),
                updated_at=datetime.now(ZoneInfo("UTC")),
            )

            conflicting_response = TaskResponse.model_validate(conflicting_task)

            self.action_card = AiActionCardResponse(
                type=AiCardType.conflictAlert,
                task=proposed_response,
                conflicting_task=conflicting_response,
                free_slots=alt_slots[:3],
                message=f"Conflict with '{conflicting_task.title}'",
            )

            return {
                "status": "conflict",
                "message": f"Time overlaps with existing task '{conflicting_task.title}' from {conflicting_task.start_time.strftime('%H:%M')} to {conflicting_task.end_time.strftime('%H:%M')}.",
                "conflicting_task": conflicting_response.model_dump(mode="json", by_alias=True),
                "alternative_free_slots": [s.model_dump(mode="json", by_alias=True) for s in alt_slots[:3]],
            }

        # Create task in DB
        task = Task(
            user_id=self.user.id,
            title=title,
            description=description,
            start_time=dt_start,
            end_time=dt_end,
            priority=p_enum.value,
            status=TaskStatus.pending.value,
            is_voice_created=self.is_voice,
            tags=[],
        )
        self.db.add(task)
        self.db.flush()

        # Create reminder
        offset = remind_before_minutes if remind_before_minutes is not None else self.user.default_reminder_offset_minutes
        user_tz = ZoneInfo(tz_name)
        now_user = datetime.now(user_tz)
        if offset is not None and offset > 0:
            remind_time = dt_start - timedelta(minutes=offset)
            if remind_time <= now_user and dt_start > now_user:
                offset = 0

        if offset is not None and offset >= 0:
            ReminderService.sync_task_reminder(self.db, task, offset_minutes=offset)

        self.db.commit()
        self.db.refresh(task)

        task_response = TaskResponse.model_validate(task)
        self.tasks_mutated = True
        self.action_card = AiActionCardResponse(
            type=AiCardType.taskCreated,
            task=task_response,
            message="Task created successfully",
        )

        return {
            "status": "success",
            "message": f"Task '{task.title}' created successfully.",
            "task": task_response.model_dump(mode="json", by_alias=True),
        }

    def get_tasks(
        self,
        start_date: Optional[str] = None,
        end_date: Optional[str] = None,
        status: Optional[str] = None,
        priority: Optional[str] = None,
    ) -> Dict[str, Any]:
        """
        Retrieves user tasks filtered by date range, status, or priority.
        """
        tz_name = self.user.timezone or "Africa/Cairo"
        query = self.db.query(Task).filter(Task.user_id == self.user.id)

        if start_date:
            dt_s = parse_datetime(start_date, tz_name)
            query = query.filter(Task.end_time >= dt_s)
        if end_date:
            dt_e = parse_datetime(end_date, tz_name)
            query = query.filter(Task.start_time <= dt_e)
        if status:
            query = query.filter(Task.status == status.lower())
        if priority:
            query = query.filter(Task.priority == priority.lower())

        tasks = query.order_by(Task.start_time.asc()).limit(50).all()
        task_list = [TaskResponse.model_validate(t).model_dump(mode="json", by_alias=True) for t in tasks]

        return {
            "count": len(task_list),
            "tasks": task_list,
        }

    def find_free_slots(
        self,
        date: str,
        min_duration_minutes: int = 30,
    ) -> Dict[str, Any]:
        """
        Finds free time slots in user's schedule on a specific date.
        """
        tz_name = self.user.timezone or "Africa/Cairo"
        dt = parse_datetime(date, tz_name)
        target_date = dt.date()

        slots = ScheduleService.calculate_free_slots(
            db=self.db,
            user=self.user,
            start_date=target_date,
            end_date=target_date,
            min_duration_minutes=min_duration_minutes,
        )

        self.action_card = AiActionCardResponse(
            type=AiCardType.freeSlots,
            free_slots=slots[:5],
            message=f"Free slots for {target_date.strftime('%Y-%m-%d')}",
        )

        return {
            "date": target_date.strftime("%Y-%m-%d"),
            "count": len(slots),
            "free_slots": [s.model_dump(mode="json", by_alias=True) for s in slots[:5]],
        }

    def update_task(
        self,
        task_id: str,
        title: Optional[str] = None,
        start_time: Optional[str] = None,
        end_time: Optional[str] = None,
        priority: Optional[str] = None,
        status: Optional[str] = None,
        remind_before_minutes: Optional[int] = None,
    ) -> Dict[str, Any]:
        """
        Updates an existing task belonging to the user.
        """
        task = self.db.query(Task).filter(Task.id == task_id, Task.user_id == self.user.id).first()
        if not task:
            # Try to match by title if id doesn't match uuid format
            task = self.db.query(Task).filter(
                Task.user_id == self.user.id,
                Task.title.ilike(f"%{task_id}%"),
            ).first()

        if not task:
            return {"status": "error", "message": f"Task not found: '{task_id}'"}

        tz_name = self.user.timezone or "Africa/Cairo"

        if title is not None:
            task.title = title
        if start_time is not None:
            task.start_time = parse_datetime(start_time, tz_name)
        if end_time is not None:
            task.end_time = parse_datetime(end_time, tz_name)
        if priority is not None:
            try:
                task.priority = TaskPriority(priority.lower()).value
            except Exception:
                pass
        if status is not None:
            try:
                task.status = TaskStatus(status).value
            except Exception:
                pass

        if remind_before_minutes is not None or start_time is not None:
            offset = remind_before_minutes if remind_before_minutes is not None else (
                task.reminders[0].offset_minutes if task.reminders else self.user.default_reminder_offset_minutes
            )
            ReminderService.sync_task_reminder(self.db, task, offset_minutes=offset)

        self.db.commit()
        self.db.refresh(task)

        self.tasks_mutated = True
        task_response = TaskResponse.model_validate(task)

        return {
            "status": "success",
            "message": f"Task '{task.title}' updated successfully.",
            "task": task_response.model_dump(mode="json", by_alias=True),
        }

    def delete_task(
        self,
        task_id: str,
        confirm: bool = False,
    ) -> Dict[str, Any]:
        """
        Deletes a task or requests confirmation before deletion.
        """
        task = self.db.query(Task).filter(Task.id == task_id, Task.user_id == self.user.id).first()
        if not task:
            # Try matching by title
            task = self.db.query(Task).filter(
                Task.user_id == self.user.id,
                Task.title.ilike(f"%{task_id}%"),
            ).first()

        if not task:
            return {"status": "error", "message": f"Task not found: '{task_id}'"}

        task_response = TaskResponse.model_validate(task)

        if not confirm:
            self.action_card = AiActionCardResponse(
                type=AiCardType.deleteConfirm,
                task=task_response,
                message=f"Are you sure you want to delete task '{task.title}'?",
            )
            return {
                "status": "confirmation_required",
                "message": f"Please confirm deletion of '{task.title}' scheduled at {task.start_time.strftime('%Y-%m-%d %H:%M')}.",
                "task": task_response.model_dump(mode="json", by_alias=True),
            }

        # Confirmed deletion
        self.db.delete(task)
        self.db.commit()
        self.tasks_mutated = True

        return {
            "status": "success",
            "message": f"Task '{task.title}' deleted.",
            "deleted_task_id": task.id,
        }

    def break_down_goal(
        self,
        goal_title: str,
        steps: List[Dict[str, Any]],
    ) -> Dict[str, Any]:
        """
        Breaks down a goal into actionable scheduled tasks.
        """
        tz_name = self.user.timezone or "Africa/Cairo"
        created_tasks: List[TaskResponse] = []

        for step in steps:
            s_title = step.get("title", "Goal Step")
            s_start = step.get("start_time")
            s_end = step.get("end_time")

            if not s_start or not s_end:
                continue

            dt_start = parse_datetime(s_start, tz_name)
            dt_end = parse_datetime(s_end, tz_name)
            p_val = step.get("priority", "medium").lower()

            task = Task(
                user_id=self.user.id,
                title=f"{goal_title}: {s_title}",
                description=step.get("description"),
                start_time=dt_start,
                end_time=dt_end,
                priority=p_val,
                status=TaskStatus.pending.value,
                is_voice_created=self.is_voice,
                tags=["goal-breakdown"],
            )
            self.db.add(task)
            self.db.flush()
            ReminderService.sync_task_reminder(self.db, task, offset_minutes=30)
            created_tasks.append(TaskResponse.model_validate(task))

        self.db.commit()
        if created_tasks:
            self.tasks_mutated = True
            self.action_card = AiActionCardResponse(
                type=AiCardType.taskCreated,
                task=created_tasks[0],
                message=f"Created {len(created_tasks)} steps for goal '{goal_title}'",
            )

        return {
            "status": "success",
            "goal": goal_title,
            "created_count": len(created_tasks),
            "tasks": [t.model_dump(mode="json", by_alias=True) for t in created_tasks],
        }

    def stop_recurring_task(
        self,
        search_query: str,
        delete_future: bool = True,
    ) -> Dict[str, Any]:
        """
        Stops an active recurring task series matching search_query.
        """
        search_fmt = f"%{search_query.strip()}%"
        matched_task = (
            self.db.query(Task)
            .filter(
                Task.user_id == self.user.id,
                Task.is_recurrence_active.is_(True),
                Task.recurrence_type != "none",
                Task.recurrence_group_id.isnot(None),
                or_(
                    Task.title.ilike(search_fmt),
                    Task.description.ilike(search_fmt),
                ),
            )
            .order_by(Task.start_time.asc())
            .first()
        )

        if not matched_task or not matched_task.recurrence_group_id:
            return {
                "status": "not_found",
                "message": f"لم يتم العثور على مهمة متكررة نشطة تطابق '{search_query}'. / No active recurring series found matching '{search_query}'.",
            }

        group_id = matched_task.recurrence_group_id
        task_title = matched_task.title
        result = RecurrenceService.stop_recurrence_series(
            db=self.db,
            user_id=self.user.id,
            group_id=group_id,
            delete_future=delete_future,
        )

        self.tasks_mutated = True
        return {
            "status": "success",
            "message": f"تم إيقاف تكرار '{task_title}' بنجاح ومسح {result['deletedFutureCount']} مواعيد قادمة مع الاحتفاظ بالسجل السابق.",
            "title": task_title,
            "groupId": group_id,
            "deletedFutureCount": result["deletedFutureCount"],
        }

    def dispatch(self, tool_name: str, args: Dict[str, Any]) -> Dict[str, Any]:
        """
        Dispatches a tool call dynamically to the matching method.
        """
        method = getattr(self, tool_name, None)
        if not method or not callable(method):
            return {"status": "error", "message": f"Unknown tool '{tool_name}'"}
        try:
            return method(**args)
        except Exception as e:
            logger.error(f"Error executing tool '{tool_name}' with args {args}: {e}", exc_info=True)
            return {"status": "error", "message": f"Error executing tool {tool_name}: {str(e)}"}


# Tool function stubs for Gemini Function Declarations
def create_task(
    title: str,
    start_time: str,
    end_time: str,
    description: Optional[str] = None,
    priority: str = "medium",
    remind_before_minutes: Optional[int] = 30,
    force: bool = False,
    recurrence_type: str = "none",
    recurrence_days: Optional[List[str]] = None,
    recurrence_end_date: Optional[str] = None,
    recurrence_count: Optional[int] = None,
) -> Dict[str, Any]:
    """Create a new task in user calendar. Checks for schedule conflicts unless force is True. Supports recurrence.
    Args:
        title: Title/name of the task.
        start_time: ISO-8601 formatted start time (e.g. 2026-11-21T15:00:00+02:00).
        end_time: ISO-8601 formatted end time (e.g. 2026-11-21T16:00:00+02:00).
        description: Optional notes or description.
        priority: One of 'urgent', 'high', 'medium', 'low'.
        remind_before_minutes: Minutes before start_time to trigger reminder (e.g. 0 to remind exactly at start_time, or 15/30). IMPORTANT: Set to 0 when reminding at or after short durations (e.g., 'remind me in 1 minute', 'فكرني بعد دقيقة').
        force: If True, schedules despite conflicts.
        recurrence_type: Recurrence mode ('none', 'daily', 'weekly', 'monthly').
        recurrence_days: For weekly recurring tasks, list of 3-letter lowercase weekdays e.g. ['sun', 'tue'].
        recurrence_end_date: Optional ISO-8601 end cutoff for recurrence.
        recurrence_count: Optional maximum number of total occurrences.
    """
    return {}


def get_tasks(
    start_date: Optional[str] = None,
    end_date: Optional[str] = None,
    status: Optional[str] = None,
    priority: Optional[str] = None,
) -> Dict[str, Any]:
    """Retrieve user tasks filtered by date range, status, or priority.
    Args:
        start_date: Optional ISO-8601 or YYYY-MM-DD start filter.
        end_date: Optional ISO-8601 or YYYY-MM-DD end filter.
        status: Filter by status ('pending', 'inProgress', 'completed', 'cancelled').
        priority: Filter by priority ('urgent', 'high', 'medium', 'low').
    """
    return {}


def find_free_slots(
    date: str,
    min_duration_minutes: int = 30,
) -> Dict[str, Any]:
    """Find available free slots/windows in user schedule on a specific date.
    Args:
        date: Target date in YYYY-MM-DD format (e.g. 2026-11-21).
        min_duration_minutes: Minimum duration in minutes for free slots (default: 30).
    """
    return {}


def update_task(
    task_id: str,
    title: Optional[str] = None,
    start_time: Optional[str] = None,
    end_time: Optional[str] = None,
    priority: Optional[str] = None,
    status: Optional[str] = None,
    remind_before_minutes: Optional[int] = None,
) -> Dict[str, Any]:
    """Update an existing task belonging to the user.
    Args:
        task_id: The ID (or unique title) of the task to update.
        title: New title.
        start_time: New ISO-8601 start time.
        end_time: New ISO-8601 end time.
        priority: 'urgent', 'high', 'medium', 'low'.
        status: 'pending', 'inProgress', 'completed', 'cancelled'.
        remind_before_minutes: New reminder offset.
    """
    return {}


def delete_task(
    task_id: str,
    confirm: bool = False,
) -> Dict[str, Any]:
    """Delete a task. If confirm is False, requests confirmation from user.
    Args:
        task_id: ID or title of the task to delete.
        confirm: Must be True to execute deletion, False to request user confirmation.
    """
    return {}


def break_down_goal(
    goal_title: str,
    steps: List[Dict[str, Any]],
) -> Dict[str, Any]:
    """Break down a high-level goal into actionable scheduled tasks.
    Args:
        goal_title: Title of the overarching goal.
        steps: List of step dictionaries, each with 'title', 'start_time', 'end_time', and optional 'description', 'priority'.
    """
    return {}


def stop_recurring_task(
    search_query: str,
    delete_future: bool = True,
) -> Dict[str, Any]:
    """Stop an active recurring task series matching a search keyword or title.
    Args:
        search_query: Keyword or title to find the recurring task (e.g. 'دكتور', 'gym', 'meeting').
        delete_future: If True, deletes future uncompleted occurrences while preserving past/completed ones.
    """
    return {}


GEMINI_TOOL_DEFINITIONS = [
    create_task,
    get_tasks,
    find_free_slots,
    update_task,
    delete_task,
    break_down_goal,
    stop_recurring_task,
]

