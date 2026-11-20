from datetime import datetime
from typing import Optional, List
from pydantic import Field
from app.schemas.common import CamelModel, AiCardType, MessageSender
from app.schemas.task import TaskResponse, TaskCreate
from app.schemas.free_slot import FreeSlotResponse


class AiActionCardResponse(CamelModel):
    type: AiCardType
    task: Optional[TaskResponse] = None
    conflicting_task: Optional[TaskResponse] = None
    free_slots: List[FreeSlotResponse] = Field(default_factory=list)
    message: Optional[str] = None
    is_executed: bool = False
    is_undone: bool = False


class ChatMessageResponse(CamelModel):
    id: str
    sender: MessageSender
    text: str
    timestamp: datetime
    is_voice: bool = False
    audio_duration_seconds: Optional[int] = None
    action_card: Optional[AiActionCardResponse] = None


class AssistantMessageRequest(CamelModel):
    text: str = Field(..., min_length=1)


class AssistantResponse(CamelModel):
    assistant_message: ChatMessageResponse
    action_card: Optional[AiActionCardResponse] = None
    tasks_mutated: bool = False
    transcript: Optional[str] = None


class ResolveConflictRequest(CamelModel):
    task: TaskCreate
    selected_slot: Optional[FreeSlotResponse] = None
    force: bool = False
