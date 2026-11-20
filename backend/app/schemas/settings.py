from typing import Optional
from pydantic import Field, field_validator
from app.schemas.common import CamelModel


class UserSettingsResponse(CamelModel):
    language: str = "ar"
    theme_mode: str = "dark"
    working_hours_start: str = "09:00"
    working_hours_end: str = "22:00"
    default_reminder_offset_minutes: int = 30
    timezone: str = "Africa/Cairo"
    notifications_enabled: bool = True
    sound_enabled: bool = True
    vibration_enabled: bool = True


class UserSettingsUpdate(CamelModel):
    language: Optional[str] = None
    theme_mode: Optional[str] = None
    working_hours_start: Optional[str] = None
    working_hours_end: Optional[str] = None
    default_reminder_offset_minutes: Optional[int] = None
    timezone: Optional[str] = None
    notifications_enabled: Optional[bool] = None
    sound_enabled: Optional[bool] = None
    vibration_enabled: Optional[bool] = None

    @field_validator("working_hours_start", "working_hours_end")
    @classmethod
    def validate_time_format(cls, v: Optional[str]) -> Optional[str]:
        if v is not None:
            parts = v.split(":")
            if len(parts) != 2:
                raise ValueError("Time must be in HH:MM format")
            h, m = int(parts[0]), int(parts[1])
            if not (0 <= h <= 23 and 0 <= m <= 59):
                raise ValueError("Invalid hour or minute")
        return v
