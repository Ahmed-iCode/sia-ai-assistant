import os
import pytest
from datetime import datetime, timezone
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

# Set test environment
os.environ["DATABASE_URL"] = "sqlite:///:memory:"
os.environ["SECRET_KEY"] = "test_super_secret_key_at_least_32_chars_long"
os.environ["GEMINI_API_KEY"] = os.environ.get("GEMINI_API_KEY", "test_gemini_key_for_testing_12345")
os.environ["GROQ_API_KEY"] = os.environ.get("GROQ_API_KEY", "test_groq_key_for_testing_12345")

from app.core.config import settings
settings.DATABASE_URL = "sqlite:///:memory:"
if not settings.GEMINI_API_KEY:
    settings.GEMINI_API_KEY = "test_gemini_key_for_testing_12345"
if not settings.GROQ_API_KEY:
    settings.GROQ_API_KEY = "test_groq_key_for_testing_12345"
assert settings.DATABASE_URL.startswith("sqlite"), "Safety check: Tests must run only on SQLite!"

from app.db.database import Base, get_db
from app.db.models import User
from app.core.security import get_password_hash, create_access_token
from app.main import app

# In-memory SQLite engine for tests with StaticPool
TEST_DATABASE_URL = "sqlite:///:memory:"
engine = create_engine(
    TEST_DATABASE_URL,
    connect_args={"check_same_thread": False},
    poolclass=StaticPool,
)
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


@pytest.fixture(scope="function")
def db_session():
    """Create fresh tables for each test and tear down after."""
    Base.metadata.create_all(bind=engine)
    session = TestingSessionLocal()
    try:
        yield session
    finally:
        session.close()
        Base.metadata.drop_all(bind=engine)


@pytest.fixture(scope="function")
def client(db_session):
    """Test client with overridden get_db dependency."""
    def override_get_db():
        try:
            yield db_session
        finally:
            pass

    app.dependency_overrides[get_db] = override_get_db
    with TestClient(app) as test_client:
        yield test_client
    app.dependency_overrides.clear()


@pytest.fixture
def auth_user(db_session):
    """Primary authenticated user fixture."""
    user = User(
        email="ahmed@example.com",
        name="Ahmed Mahmoud",
        hashed_password=get_password_hash("password123"),
        working_hours_start="09:00",
        working_hours_end="22:00",
        timezone="Africa/Cairo",
        default_reminder_offset_minutes=30,
    )
    db_session.add(user)
    db_session.commit()
    db_session.refresh(user)

    token = create_access_token(subject=user.id)
    headers = {"Authorization": f"Bearer {token}"}
    return {"user": user, "token": token, "headers": headers}


@pytest.fixture
def other_user(db_session):
    """Secondary user fixture for testing multi-tenant isolation."""
    user = User(
        email="other@example.com",
        name="Other User",
        hashed_password=get_password_hash("password123"),
        working_hours_start="09:00",
        working_hours_end="17:00",
        timezone="Africa/Cairo",
    )
    db_session.add(user)
    db_session.commit()
    db_session.refresh(user)

    token = create_access_token(subject=user.id)
    headers = {"Authorization": f"Bearer {token}"}
    return {"user": user, "token": token, "headers": headers}
