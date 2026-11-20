from datetime import datetime, timezone
from enum import Enum
from pydantic import BaseModel, ConfigDict, model_validator


def to_camel(string: str) -> str:
    words = string.split("_")
    return words[0] + "".join(word.capitalize() for word in words[1:])


class CamelModel(BaseModel):
    model_config = ConfigDict(
        alias_generator=to_camel,
        populate_by_name=True,
        from_attributes=True,
    )

    @model_validator(mode="after")
    def _ensure_utc_datetimes(self):
        for field_name, field_val in self.__dict__.items():
            if isinstance(field_val, datetime) and field_val.tzinfo is None:
                setattr(self, field_name, field_val.replace(tzinfo=timezone.utc))
            elif isinstance(field_val, list):
                new_list = []
                changed = False
                for item in field_val:
                    if isinstance(item, datetime) and item.tzinfo is None:
                        new_list.append(item.replace(tzinfo=timezone.utc))
                        changed = True
                    else:
                        new_list.append(item)
                if changed:
                    setattr(self, field_name, new_list)
        return self


class TaskPriority(str, Enum):
    urgent = "urgent"
    high = "high"
    medium = "medium"
    low = "low"


class TaskStatus(str, Enum):
    pending = "pending"
    inProgress = "inProgress"
    completed = "completed"
    cancelled = "cancelled"


class ReminderType(str, Enum):
    notification = "notification"
    alarm = "alarm"
    email = "email"


class MessageSender(str, Enum):
    user = "user"
    assistant = "assistant"
    system = "system"


class AiCardType(str, Enum):
    taskCreated = "taskCreated"
    conflictAlert = "conflictAlert"
    freeSlots = "freeSlots"
    deleteConfirm = "deleteConfirm"
