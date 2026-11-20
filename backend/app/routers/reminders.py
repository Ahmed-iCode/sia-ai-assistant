from typing import List
from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session

from app.core.security import get_current_user
from app.db.database import get_db
from app.db.models import Reminder, PushSubscription, Task, User
from app.schemas.reminder import (
    ReminderResponse,
    PushSubscriptionCreate,
    PushSubscriptionResponse,
)

router = APIRouter(prefix="/reminders", tags=["Reminders"])


@router.get("/upcoming", response_model=List[ReminderResponse])
def get_upcoming_reminders(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    reminders = (
        db.query(Reminder)
        .join(Task)
        .filter(
            Reminder.user_id == current_user.id,
            Task.status != "completed",
            Task.status != "cancelled",
        )
        .order_by(Reminder.remind_at.asc())
        .limit(50)
        .all()
    )
    return reminders


@router.post(
    "/push-subscribe",
    response_model=PushSubscriptionResponse,
    status_code=status.HTTP_201_CREATED,
)
def subscribe_push(
    sub_in: PushSubscriptionCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    # Check if subscription endpoint exists already
    existing = (
        db.query(PushSubscription)
        .filter(
            PushSubscription.user_id == current_user.id,
            PushSubscription.endpoint == sub_in.endpoint,
        )
        .first()
    )
    if existing:
        existing.keys = sub_in.keys
        existing.device_type = sub_in.device_type
        db.commit()
        db.refresh(existing)
        return existing

    sub = PushSubscription(
        user_id=current_user.id,
        endpoint=sub_in.endpoint,
        keys=sub_in.keys,
        device_type=sub_in.device_type,
    )
    db.add(sub)
    db.commit()
    db.refresh(sub)
    return sub
