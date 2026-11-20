from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.core.security import get_current_user
from app.db.database import get_db
from app.db.models import User
from app.schemas.settings import UserSettingsResponse, UserSettingsUpdate

router = APIRouter(prefix="/settings", tags=["User Settings"])


@router.get("", response_model=UserSettingsResponse)
def get_user_settings(current_user: User = Depends(get_current_user)):
    return UserSettingsResponse(
        language=current_user.language,
        theme_mode=current_user.theme_mode,
        working_hours_start=current_user.working_hours_start,
        working_hours_end=current_user.working_hours_end,
        default_reminder_offset_minutes=current_user.default_reminder_offset_minutes,
        timezone=current_user.timezone,
        notifications_enabled=current_user.notifications_enabled,
        sound_enabled=current_user.sound_enabled,
        vibration_enabled=current_user.vibration_enabled,
    )


@router.put("", response_model=UserSettingsResponse)
def update_user_settings(
    settings_in: UserSettingsUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    update_data = settings_in.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        if hasattr(current_user, field) and value is not None:
            setattr(current_user, field, value)

    db.commit()
    db.refresh(current_user)

    return UserSettingsResponse(
        language=current_user.language,
        theme_mode=current_user.theme_mode,
        working_hours_start=current_user.working_hours_start,
        working_hours_end=current_user.working_hours_end,
        default_reminder_offset_minutes=current_user.default_reminder_offset_minutes,
        timezone=current_user.timezone,
        notifications_enabled=current_user.notifications_enabled,
        sound_enabled=current_user.sound_enabled,
        vibration_enabled=current_user.vibration_enabled,
    )
