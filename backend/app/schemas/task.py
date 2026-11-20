from datetime import datetime
from typing import Optional, List
from pydantic import Field, model_validator
from app.schemas.common import CamelModel, TaskPriority, TaskStatus
from app.schemas.reminder import ReminderResponse
from app.schemas.free_slot import FreeSlotResponse


class TaskCreate(CamelModel):
    title: str = Field(..., min_length=1, max_length=255)
    description: Optional[str] = None
    start_time: datetime
    end_time: datetime
    priority: TaskPriority = TaskPriority.medium
    status: TaskStatus = TaskStatus.pending
    remind_before_minutes: Optional[int] = 30
    is_voice_created: bool = False
    tags: List[str] = Field(default_factory=list)
    force: bool = False

    @model_validator(mode="after")
    def validate_time_order(self):
        if self.end_time <= self.start_time:
            raise ValueError("end_time must be strictly after start_time")
        return self


class TaskUpdate(CamelModel):
    title: Optional[str] = Field(None, min_length=1, max_length=255)
    description: Optional[str] = None
    start_time: Optional[datetime] = None
    end_time: Optional[datetime] = None
    priority: Optional[TaskPriority] = None
    status: Optional[TaskStatus] = None
    remind_before_minutes: Optional[int] = None
    is_voice_created: Optional[bool] = None
    tags: Optional[List[str]] = None
    force: bool = False


class TaskResponse(CamelModel):
    id: str
    title: str
    description: Optional[str] = None
    start_time: datetime
    end_time: datetime
    priority: TaskPriority
    status: TaskStatus
    reminders: List[ReminderResponse] = Field(default_factory=list)
    is_voice_created: bool = False
    tags: List[str] = Field(default_factory=list)
    created_at: datetime
    updated_at: datetime


class ConflictDetail(CamelModel):
    conflicting_task: TaskResponse
    proposed_task: TaskCreate
    alternative_free_slots: List[FreeSlotResponse]
    message: str
