from app.schemas.common import (
    to_camel,
    CamelModel,
    TaskPriority,
    TaskStatus,
    ReminderType,
    MessageSender,
    AiCardType,
)
from app.schemas.auth import UserRegister, UserLogin, Token, UserResponse
from app.schemas.settings import UserSettingsResponse, UserSettingsUpdate
from app.schemas.reminder import (
    ReminderResponse,
    ReminderCreate,
    PushSubscriptionCreate,
    PushSubscriptionResponse,
)
from app.schemas.free_slot import FreeSlotResponse
from app.schemas.task import TaskCreate, TaskUpdate, TaskResponse, ConflictDetail
from app.schemas.action_card import (
    AiActionCardResponse,
    ChatMessageResponse,
    AssistantMessageRequest,
    AssistantResponse,
    ResolveConflictRequest,
)
