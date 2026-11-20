from datetime import datetime
from typing import Optional
from pydantic import EmailStr, Field
from app.schemas.common import CamelModel
from app.schemas.settings import UserSettingsResponse


class UserRegister(CamelModel):
    name: str = Field(..., min_length=2, max_length=100)
    email: EmailStr
    password: str = Field(..., min_length=6, max_length=100)


class UserLogin(CamelModel):
    email: EmailStr
    password: str


class Token(CamelModel):
    access_token: str
    token_type: str = "bearer"


class UserResponse(CamelModel):
    id: str
    name: str
    email: str
    is_active: bool
    settings: UserSettingsResponse
    created_at: datetime
    updated_at: datetime
