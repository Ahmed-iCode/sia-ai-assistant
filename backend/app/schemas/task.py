from datetime import datetime
from typing import Optional, List
from pydantic import Field, model_validator, field_validator
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
    recurrence_type: str = "none"
    recurrence_days: List[str] = Field(default_factory=list)
    recurrence_end_date: Optional[datetime] = None
    recurrence_count: Optional[int] = None
    recurrence_group_id: Optional[str] = None
    is_recurrence_active: bool = True
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
    recurrence_type: Optional[str] = None
    recurrence_days: Optional[List[str]] = None
    recurrence_end_date: Optional[datetime] = None
    recurrence_count: Optional[int] = None
    is_recurrence_active: Optional[bool] = None
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
    recurrence_type: str = "none"
    recurrence_days: List[str] = Field(default_factory=list)
    recurrence_end_date: Optional[datetime] = None
    recurrence_count: Optional[int] = None
    recurrence_group_id: Optional[str] = None
    is_recurrence_active: bool = True
    created_at: datetime
    updated_at: datetime

    @field_validator("recurrence_days", mode="before")
    @classmethod
    def parse_recurrence_days(cls, v):
        if isinstance(v, str):
            return [d.strip().lower() for d in v.split(",") if d.strip()]
        if v is None:
            return []
        return list(v)


class StopRecurrenceResponse(CamelModel):
    group_id: str
    stopped: bool
    deleted_future_count: int


class ConflictDetail(CamelModel):
    conflicting_task: TaskResponse
    proposed_task: TaskCreate
    alternative_free_slots: List[FreeSlotResponse]
    message: str


class ExtractedTaskDraft(CamelModel):
    id: Optional[str] = None
    title: str = Field(..., min_length=1, max_length=255)
    description: Optional[str] = None
    start_time: datetime
    end_time: datetime
    priority: TaskPriority = TaskPriority.medium
    category: Optional[str] = None
    reminder_minutes: Optional[int] = 15


class FileExtractionResponse(CamelModel):
    reply: str
    extracted_tasks: List[ExtractedTaskDraft]


class BatchTaskCreate(CamelModel):
    tasks: List[TaskCreate] = Field(..., min_length=1, max_length=50)


class BatchTaskResponse(CamelModel):
    created_count: int
    tasks: List[TaskResponse]

