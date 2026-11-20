from datetime import datetime
from typing import Optional, Any, Dict
from pydantic import BaseModel, Field
from app.schemas.common import CamelModel, ReminderType


class ReminderResponse(CamelModel):
    id: str
    task_id: str
    remind_at: datetime
    offset_minutes: int = 30
    type: ReminderType = ReminderType.notification
    is_triggered: bool = False


class ReminderCreate(CamelModel):
    task_id: str
    offset_minutes: int = 30
    type: ReminderType = ReminderType.notification


class PushSubscriptionCreate(CamelModel):
    endpoint: str
    keys: Dict[str, Any]
    device_type: Optional[str] = "web"


class PushSubscriptionResponse(CamelModel):
    id: str
    endpoint: str
    device_type: Optional[str]
    created_at: datetime
