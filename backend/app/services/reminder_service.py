import logging
from datetime import datetime, timedelta, timezone
from typing import Optional, List
from sqlalchemy.orm import Session

from app.db.models import Reminder, Task

logger = logging.getLogger("reminder_scheduler")


class ReminderService:
    @staticmethod
    def sync_task_reminder(
        db: Session,
        task: Task,
        offset_minutes: Optional[int] = 30,
        reminder_type: str = "notification",
    ) -> Optional[Reminder]:
        """
        Creates or updates a reminder linked to a task based on offset_minutes.
        If offset_minutes is negative (< 0) or None, any existing reminder is removed.
        If offset_minutes is 0, the reminder is scheduled exactly at task.start_time.
        """
        existing_reminder = (
            db.query(Reminder)
            .filter(Reminder.task_id == task.id)
            .first()
        )

        if offset_minutes is None or offset_minutes < 0:
            if existing_reminder:
                db.delete(existing_reminder)
                db.flush()
            return None

        remind_at = task.start_time - timedelta(minutes=offset_minutes)

        if existing_reminder:
            existing_reminder.remind_at = remind_at
            existing_reminder.offset_minutes = offset_minutes
            existing_reminder.type = reminder_type
            existing_reminder.is_triggered = False
            existing_reminder.is_sent = False
            existing_reminder.sent_at = None
            db.flush()
            return existing_reminder
        else:
            new_reminder = Reminder(
                user_id=task.user_id,
                task_id=task.id,
                remind_at=remind_at,
                offset_minutes=offset_minutes,
                type=reminder_type,
                is_triggered=False,
                is_sent=False,
            )
            db.add(new_reminder)
            db.flush()
            return new_reminder

    @staticmethod
    def check_and_dispatch_due_reminders(db: Session) -> int:
        """
        Queries all unsent reminders whose remind_at <= now,
        marks them as sent, and dispatches notification.
        """
        now = datetime.now(timezone.utc)

        due_reminders: List[Reminder] = (
            db.query(Reminder)
            .join(Task)
            .filter(
                Reminder.is_sent == False,
                Reminder.remind_at <= now,
                Task.status != "cancelled",
                Task.status != "completed",
            )
            .all()
        )

        if not due_reminders:
            return 0

        dispatched_count = 0
        for reminder in due_reminders:
            reminder.is_triggered = True
            reminder.is_sent = True
            reminder.sent_at = now
            dispatched_count += 1

            logger.info(
                f"[REMINDER DISPATCH] Task: '{reminder.task.title}' | "
                f"Scheduled for: {reminder.task.start_time} | "
                f"User ID: {reminder.user_id} | "
                f"Offset: {reminder.offset_minutes}m before"
            )

        db.commit()
        return dispatched_count
