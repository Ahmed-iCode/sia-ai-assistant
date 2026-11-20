from datetime import datetime, date, time, timedelta, timezone
from typing import List, Optional
import pytz
from sqlalchemy.orm import Session
from sqlalchemy import and_

from app.db.models import Task, User
from app.schemas.free_slot import FreeSlotResponse


def ensure_aware(dt: datetime, tz_name: str = "Africa/Cairo") -> datetime:
    """Ensure datetime is timezone-aware."""
    if dt.tzinfo is None:
        tz = pytz.timezone(tz_name)
        return tz.localize(dt)
    return dt


class ScheduleService:
    @staticmethod
    def check_conflicts(
        db: Session,
        user_id: str,
        start_time: datetime,
        end_time: datetime,
        exclude_task_id: Optional[str] = None,
    ) -> List[Task]:
        """
        Detects schedule conflicts.
        A conflict exists if an existing non-cancelled task overlaps with [start_time, end_time]:
        task.start_time < end_time AND task.end_time > start_time.
        """
        query = db.query(Task).filter(
            Task.user_id == user_id,
            Task.status != "cancelled",
            Task.start_time < end_time,
            Task.end_time > start_time,
        )
        if exclude_task_id:
            query = query.filter(Task.id != exclude_task_id)

        return query.order_by(Task.start_time.asc()).all()

    @staticmethod
    def calculate_free_slots(
        db: Session,
        user: User,
        start_date: date,
        end_date: date,
        min_duration_minutes: int = 30,
        max_slots_per_day: int = 10,
    ) -> List[FreeSlotResponse]:
        """
        Calculates open availability windows within user's working hours.
        Respects user working_hours_start (e.g. 09:00), working_hours_end (e.g. 22:00),
        and timezone (default Africa/Cairo).
        """
        tz_name = user.timezone or "Africa/Cairo"
        try:
            user_tz = pytz.timezone(tz_name)
        except Exception:
            user_tz = pytz.timezone("Africa/Cairo")

        # Parse working hours
        start_h, start_m = [int(p) for p in user.working_hours_start.split(":")]
        end_h, end_m = [int(p) for p in user.working_hours_end.split(":")]

        free_slots: List[FreeSlotResponse] = []

        curr_date = start_date
        while curr_date <= end_date:
            day_start = user_tz.localize(
                datetime.combine(curr_date, time(start_h, start_m))
            )
            day_end = user_tz.localize(
                datetime.combine(curr_date, time(end_h, end_m))
            )

            # Query non-cancelled tasks for this day
            tasks = (
                db.query(Task)
                .filter(
                    Task.user_id == user.id,
                    Task.status != "cancelled",
                    Task.start_time < day_end,
                    Task.end_time > day_start,
                )
                .order_by(Task.start_time.asc())
                .all()
            )

            day_slots_count = 0
            pointer = day_start

            for task in tasks:
                task_start = ensure_aware(task.start_time, tz_name).astimezone(user_tz)
                task_end = ensure_aware(task.end_time, tz_name).astimezone(user_tz)

                if task_start > pointer:
                    gap_duration = int((task_start - pointer).total_seconds() / 60)
                    if gap_duration >= min_duration_minutes:
                        free_slots.append(
                            FreeSlotResponse(
                                start=pointer,
                                end=task_start,
                                duration_minutes=gap_duration,
                            )
                        )
                        day_slots_count += 1
                        if day_slots_count >= max_slots_per_day:
                            break

                if task_end > pointer:
                    pointer = task_end

            if day_slots_count < max_slots_per_day and pointer < day_end:
                gap_duration = int((day_end - pointer).total_seconds() / 60)
                if gap_duration >= min_duration_minutes:
                    free_slots.append(
                        FreeSlotResponse(
                            start=pointer,
                            end=day_end,
                            duration_minutes=gap_duration,
                        )
                    )

            curr_date += timedelta(days=1)

        return free_slots
