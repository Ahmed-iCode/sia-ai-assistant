import uuid
from datetime import datetime, timezone
from sqlalchemy import (
    Column,
    String,
    Boolean,
    Integer,
    DateTime,
    ForeignKey,
    Text,
    Index,
    JSON,
)
from sqlalchemy.orm import relationship

from app.db.database import Base


def generate_uuid() -> str:
    return str(uuid.uuid4())


def utc_now() -> datetime:
    return datetime.now(timezone.utc)


class User(Base):
    __tablename__ = "users"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    email = Column(String(255), unique=True, index=True, nullable=False)
    hashed_password = Column(String(255), nullable=False)
    name = Column(String(100), nullable=False)
    is_active = Column(Boolean, default=True, nullable=False)

    # User Settings / Preferences
    language = Column(String(10), default="ar", nullable=False)
    theme_mode = Column(String(20), default="dark", nullable=False)
    working_hours_start = Column(String(5), default="09:00", nullable=False)
    working_hours_end = Column(String(5), default="22:00", nullable=False)
    default_reminder_offset_minutes = Column(Integer, default=30, nullable=False)
    timezone = Column(String(50), default="Africa/Cairo", nullable=False)
    notifications_enabled = Column(Boolean, default=True, nullable=False)
    sound_enabled = Column(Boolean, default=True, nullable=False)
    vibration_enabled = Column(Boolean, default=True, nullable=False)

    created_at = Column(DateTime(timezone=True), default=utc_now, nullable=False)
    updated_at = Column(DateTime(timezone=True), default=utc_now, onupdate=utc_now, nullable=False)

    # Relationships
    tasks = relationship("Task", back_populates="user", cascade="all, delete-orphan")
    reminders = relationship("Reminder", back_populates="user", cascade="all, delete-orphan")
    chat_messages = relationship("ChatMessage", back_populates="user", cascade="all, delete-orphan")
    push_subscriptions = relationship("PushSubscription", back_populates="user", cascade="all, delete-orphan")


class Task(Base):
    __tablename__ = "tasks"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    user_id = Column(String(36), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    title = Column(String(255), nullable=False)
    description = Column(Text, nullable=True)
    start_time = Column(DateTime(timezone=True), nullable=False, index=True)
    end_time = Column(DateTime(timezone=True), nullable=False)
    priority = Column(String(20), default="medium", nullable=False)
    status = Column(String(20), default="pending", nullable=False)
    is_voice_created = Column(Boolean, default=False, nullable=False)
    tags = Column(JSON, default=list, nullable=False)

    # Recurrence Fields
    recurrence_type = Column(String(20), default="none", server_default="none", nullable=False)
    recurrence_days = Column(String(50), nullable=True)
    recurrence_end_date = Column(DateTime(timezone=True), nullable=True)
    recurrence_count = Column(Integer, nullable=True)
    recurrence_group_id = Column(String(64), nullable=True, index=True)
    is_recurrence_active = Column(Boolean, default=True, server_default="true", nullable=False)

    created_at = Column(DateTime(timezone=True), default=utc_now, nullable=False)
    updated_at = Column(DateTime(timezone=True), default=utc_now, onupdate=utc_now, nullable=False)

    # Relationships
    user = relationship("User", back_populates="tasks")
    reminders = relationship("Reminder", back_populates="task", cascade="all, delete-orphan")

    __table_args__ = (
        Index("ix_tasks_user_id_start_time", "user_id", "start_time"),
    )


class Reminder(Base):
    __tablename__ = "reminders"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    user_id = Column(String(36), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    task_id = Column(String(36), ForeignKey("tasks.id", ondelete="CASCADE"), nullable=False, index=True)
    remind_at = Column(DateTime(timezone=True), nullable=False, index=True)
    offset_minutes = Column(Integer, default=30, nullable=False)
    type = Column(String(20), default="notification", nullable=False)
    is_triggered = Column(Boolean, default=False, nullable=False)
    is_sent = Column(Boolean, default=False, nullable=False)
    sent_at = Column(DateTime(timezone=True), nullable=True)

    created_at = Column(DateTime(timezone=True), default=utc_now, nullable=False)
    updated_at = Column(DateTime(timezone=True), default=utc_now, onupdate=utc_now, nullable=False)

    # Relationships
    user = relationship("User", back_populates="reminders")
    task = relationship("Task", back_populates="reminders")

    __table_args__ = (
        Index("ix_reminders_is_sent_remind_at", "is_sent", "remind_at"),
    )


class ChatMessage(Base):
    __tablename__ = "chat_messages"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    user_id = Column(String(36), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    sender = Column(String(20), default="user", nullable=False)
    text = Column(Text, nullable=False)
    is_voice = Column(Boolean, default=False, nullable=False)
    audio_duration_seconds = Column(Integer, nullable=True)
    action_card_data = Column(JSON, nullable=True)

    timestamp = Column(DateTime(timezone=True), default=utc_now, nullable=False, index=True)

    # Relationships
    user = relationship("User", back_populates="chat_messages")


class PushSubscription(Base):
    __tablename__ = "push_subscriptions"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    user_id = Column(String(36), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    endpoint = Column(Text, nullable=False)
    keys = Column(JSON, nullable=False)
    device_type = Column(String(20), nullable=True)

    created_at = Column(DateTime(timezone=True), default=utc_now, nullable=False)

    # Relationships
    user = relationship("User", back_populates="push_subscriptions")
