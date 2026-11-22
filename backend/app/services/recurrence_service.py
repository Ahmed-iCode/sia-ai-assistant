import logging
import uuid
import calendar
from datetime import datetime, date, timedelta, timezone, time
from typing import List, Optional, Set, Dict, Any
from zoneinfo import ZoneInfo
from sqlalchemy.orm import Session
from sqlalchemy import or_

from app.db.models import Task, User, utc_now
from app.schemas.task import TaskCreate, TaskResponse
from app.schemas.common import TaskStatus, TaskPriority
from app.services.reminder_service import ReminderService

logger = logging.getLogger(__name__)

WEEKDAY_TO_INT = {
    "mon": 0, "tue": 1, "wed": 2, "thu": 3, "fri": 4, "sat": 5, "sun": 6
}
INT_TO_WEEKDAY = {v: k for k, v in WEEKDAY_TO_INT.items()}


def normalize_recurrence_days(days: Optional[List[str]]) -> List[str]:
    """Normalizes weekday strings to lowercase 3-letter codes."""
    if not days:
        return []
    result = []
    for d in days:
        if not d:
            continue
        cleaned = d.strip().lower()[:3]
        if cleaned in WEEKDAY_TO_INT and cleaned not in result:
            result.append(cleaned)
    return result


class RecurrenceService:
    """
    Manages 30-day rolling window recurrence materialization, auto-refill,
    and series cancellation for recurring tasks.
    """

    ROLLING_WINDOW_DAYS = 30

    @classmethod
    def create_recurring_series(
        cls,
        db: Session,
        user: User,
        task_in: TaskCreate,
    ) -> Task:
        """
        Creates a new recurring task series with a 30-day rolling window of concrete Task instances.
        Returns the primary (first) Task instance.
        """
        group_id = task_in.recurrence_group_id or str(uuid.uuid4())
        rec_type = (task_in.recurrence_type or "none").lower()

        # Parse days
        rec_days = normalize_recurrence_days(task_in.recurrence_days)
        if rec_type == "weekly" and not rec_days:
            # Default to start_time weekday
            user_tz = ZoneInfo(user.timezone or "Africa/Cairo")
            local_start = task_in.start_time.astimezone(user_tz)
            rec_days = [INT_TO_WEEKDAY[local_start.weekday()]]

        days_str = ",".join(rec_days) if rec_days else None

        # Determine user timezone
        user_tz_name = user.timezone or "Africa/Cairo"
        try:
            user_tz = ZoneInfo(user_tz_name)
        except Exception:
            user_tz = ZoneInfo("Africa/Cairo")

        now_utc = utc_now()
        horizon_utc = now_utc + timedelta(days=cls.ROLLING_WINDOW_DAYS)

        # Max end cutoff
        max_cutoff = horizon_utc
        if task_in.recurrence_end_date:
            aware_end = task_in.recurrence_end_date
            if aware_end.tzinfo is None:
                aware_end = aware_end.replace(tzinfo=timezone.utc)
            max_cutoff = min(max_cutoff, aware_end)

        duration = task_in.end_time - task_in.start_time
        if duration <= timedelta(0):
            duration = timedelta(minutes=30)

        # Generate occurrence start times in user local time
        occurrence_starts = cls._generate_occurrence_starts(
            start_time_utc=task_in.start_time,
            recurrence_type=rec_type,
            recurrence_days=rec_days,
            user_tz=user_tz,
            horizon_utc=max_cutoff,
            max_count=task_in.recurrence_count,
            existing_starts=set(),
        )

        # Ensure at least the primary start_time is included
        if not occurrence_starts:
            occurrence_starts = [task_in.start_time]

        primary_task: Optional[Task] = None
        created_tasks: List[Task] = []

        for idx, occ_start in enumerate(occurrence_starts):
            occ_end = occ_start + duration
            task = Task(
                user_id=user.id,
                title=task_in.title,
                description=task_in.description,
                start_time=occ_start,
                end_time=occ_end,
                priority=task_in.priority.value,
                status=task_in.status.value,
                is_voice_created=task_in.is_voice_created,
                tags=task_in.tags,
                recurrence_type=rec_type,
                recurrence_days=days_str,
                recurrence_end_date=task_in.recurrence_end_date,
                recurrence_count=task_in.recurrence_count,
                recurrence_group_id=group_id,
                is_recurrence_active=True,
            )
            db.add(task)
            db.flush()

            # Synchronize reminder for each occurrence
            offset = (
                task_in.remind_before_minutes
                if task_in.remind_before_minutes is not None
                else user.default_reminder_offset_minutes
            )
            if offset and offset > 0:
                ReminderService.sync_task_reminder(db=db, task=task, offset_minutes=offset)

            if idx == 0:
                primary_task = task
            created_tasks.append(task)

        db.commit()
        if primary_task:
            db.refresh(primary_task)
            return primary_task
        return created_tasks[0]

    @classmethod
    def ensure_rolling_occurrences(cls, db: Session, user_id: str) -> int:
        """
        Auto-refills active recurring series within a 30-day rolling window for the user.
        Idempotent: skips existing slots, respects count and end dates.
        Returns the number of newly materialized task occurrences.
        """
        user = db.query(User).filter(User.id == user_id).first()
        if not user:
            return 0

        user_tz_name = user.timezone or "Africa/Cairo"
        try:
            user_tz = ZoneInfo(user_tz_name)
        except Exception:
            user_tz = ZoneInfo("Africa/Cairo")

        # Find active recurring tasks
        active_tasks = (
            db.query(Task)
            .filter(
                Task.user_id == user_id,
                Task.is_recurrence_active.is_(True),
                Task.recurrence_type != "none",
                Task.recurrence_group_id.isnot(None),
            )
            .order_by(Task.start_time.asc())
            .all()
        )

        if not active_tasks:
            return 0

        # Group by recurrence_group_id
        groups: Dict[str, List[Task]] = {}
        for t in active_tasks:
            groups.setdefault(t.recurrence_group_id, []).append(t)

        now_utc = utc_now()
        horizon_utc = now_utc + timedelta(days=cls.ROLLING_WINDOW_DAYS)
        newly_created_count = 0

        for group_id, tasks_in_group in groups.items():
            representative = tasks_in_group[0]
            rec_type = representative.recurrence_type
            rec_days = (
                [d.strip().lower() for d in representative.recurrence_days.split(",") if d.strip()]
                if representative.recurrence_days
                else []
            )
            rec_end_date = representative.recurrence_end_date
            rec_count = representative.recurrence_count

            total_existing_count = len(tasks_in_group)
            if rec_count and total_existing_count >= rec_count:
                continue

            existing_starts: Set[datetime] = {
                t.start_time if t.start_time.tzinfo else t.start_time.replace(tzinfo=timezone.utc)
                for t in tasks_in_group
            }

            max_cutoff = horizon_utc
            if rec_end_date:
                aware_end = rec_end_date if rec_end_date.tzinfo else rec_end_date.replace(tzinfo=timezone.utc)
                max_cutoff = min(max_cutoff, aware_end)

            # Start generator from the earliest task's start time
            base_start = representative.start_time
            if base_start.tzinfo is None:
                base_start = base_start.replace(tzinfo=timezone.utc)

            duration = representative.end_time - representative.start_time
            if duration <= timedelta(0):
                duration = timedelta(minutes=30)

            remaining_count = (rec_count - total_existing_count) if rec_count else None

            candidate_starts = cls._generate_occurrence_starts(
                start_time_utc=base_start,
                recurrence_type=rec_type,
                recurrence_days=rec_days,
                user_tz=user_tz,
                horizon_utc=max_cutoff,
                max_count=rec_count,
                existing_starts=existing_starts,
            )

            # Filter out starts that already exist
            missing_starts = [
                s for s in candidate_starts
                if s not in existing_starts and s > now_utc
            ]

            if remaining_count is not None:
                missing_starts = missing_starts[:remaining_count]

            for s_time in missing_starts:
                e_time = s_time + duration
                new_task = Task(
                    user_id=user_id,
                    title=representative.title,
                    description=representative.description,
                    start_time=s_time,
                    end_time=e_time,
                    priority=representative.priority,
                    status=TaskStatus.pending.value,
                    is_voice_created=representative.is_voice_created,
                    tags=representative.tags,
                    recurrence_type=rec_type,
                    recurrence_days=representative.recurrence_days,
                    recurrence_end_date=rec_end_date,
                    recurrence_count=rec_count,
                    recurrence_group_id=group_id,
                    is_recurrence_active=True,
                )
                db.add(new_task)
                db.flush()

                # Sync reminder
                offset = (
                    representative.reminders[0].offset_minutes
                    if representative.reminders
                    else user.default_reminder_offset_minutes
                )
                if offset and offset > 0:
                    ReminderService.sync_task_reminder(db=db, task=new_task, offset_minutes=offset)

                existing_starts.add(s_time)
                newly_created_count += 1

        if newly_created_count > 0:
            db.commit()

        return newly_created_count

    @classmethod
    def stop_recurrence_series(
        cls,
        db: Session,
        user_id: str,
        group_id: str,
        delete_future: bool = True,
    ) -> Dict[str, Any]:
        """
        Stops a recurring series. Sets is_recurrence_active=False on all tasks in the group.
        If delete_future=True, deletes future uncompleted occurrences while preserving past/completed history.
        """
        tasks = (
            db.query(Task)
            .filter(
                Task.user_id == user_id,
                Task.recurrence_group_id == group_id,
            )
            .all()
        )

        if not tasks:
            return {"groupId": group_id, "stopped": False, "deletedFutureCount": 0}

        now_utc = utc_now()
        deleted_count = 0

        for t in tasks:
            t.is_recurrence_active = False
            t_start = t.start_time if t.start_time.tzinfo else t.start_time.replace(tzinfo=timezone.utc)
            if delete_future and t_start > now_utc and t.status != TaskStatus.completed.value:
                db.delete(t)
                deleted_count += 1

        db.commit()
        return {
            "groupId": group_id,
            "stopped": True,
            "deletedFutureCount": deleted_count,
        }

    @classmethod
    def _generate_occurrence_starts(
        cls,
        start_time_utc: datetime,
        recurrence_type: str,
        recurrence_days: List[str],
        user_tz: ZoneInfo,
        horizon_utc: datetime,
        max_count: Optional[int] = None,
        existing_starts: Optional[Set[datetime]] = None,
    ) -> List[datetime]:
        """
        Generates list of UTC datetime starts adhering to wall-clock time in user_tz.
        """
        if start_time_utc.tzinfo is None:
            start_time_utc = start_time_utc.replace(tzinfo=timezone.utc)

        local_start = start_time_utc.astimezone(user_tz)
        target_time = local_start.time()

        occurrences: List[datetime] = []
        existing = existing_starts or set()

        if recurrence_type == "daily":
            curr_date = local_start.date()
            while True:
                candidate_local = datetime.combine(curr_date, target_time, tzinfo=user_tz)
                candidate_utc = candidate_local.astimezone(timezone.utc)

                if candidate_utc > horizon_utc:
                    break

                if candidate_utc >= start_time_utc:
                    if candidate_utc not in existing:
                        occurrences.append(candidate_utc)
                        existing.add(candidate_utc)
                    if max_count and len(occurrences) >= max_count:
                        break

                curr_date += timedelta(days=1)

        elif recurrence_type == "weekly":
            target_weekdays = {WEEKDAY_TO_INT[d] for d in recurrence_days if d in WEEKDAY_TO_INT}
            if not target_weekdays:
                target_weekdays = {local_start.weekday()}

            curr_date = local_start.date()
            while True:
                if curr_date.weekday() in target_weekdays:
                    candidate_local = datetime.combine(curr_date, target_time, tzinfo=user_tz)
                    candidate_utc = candidate_local.astimezone(timezone.utc)

                    if candidate_utc > horizon_utc:
                        break

                    if candidate_utc >= start_time_utc:
                        if candidate_utc not in existing:
                            occurrences.append(candidate_utc)
                            existing.add(candidate_utc)
                        if max_count and len(occurrences) >= max_count:
                            break

                curr_date += timedelta(days=1)
                # Safeguard: stop after 365 days max search
                if (curr_date - local_start.date()).days > 365:
                    break

        elif recurrence_type == "monthly":
            m_offset = 0
            while True:
                total_months = (local_start.year * 12 + local_start.month - 1) + m_offset
                year = total_months // 12
                month = (total_months % 12) + 1
                max_day = calendar.monthrange(year, month)[1]
                day = min(local_start.day, max_day)

                candidate_local = datetime(
                    year, month, day,
                    target_time.hour, target_time.minute, target_time.second,
                    tzinfo=user_tz,
                )
                candidate_utc = candidate_local.astimezone(timezone.utc)

                if candidate_utc > horizon_utc:
                    break

                if candidate_utc >= start_time_utc:
                    if candidate_utc not in existing:
                        occurrences.append(candidate_utc)
                        existing.add(candidate_utc)
                    if max_count and len(occurrences) >= max_count:
                        break

                m_offset += 1
                if m_offset > 120:  # 10 years safeguard
                    break

        return occurrences
