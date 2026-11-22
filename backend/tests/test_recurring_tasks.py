import pytest
from datetime import datetime, timedelta, timezone
from app.db.models import Task, User, utc_now
from app.schemas.task import TaskCreate
from app.schemas.common import TaskPriority, TaskStatus
from app.services.recurrence_service import RecurrenceService
from app.ai.tools import ToolExecutor


def test_indefinite_weekly_recurrence(client, auth_user, db_session):
    """
    Test creating an indefinite weekly recurring task on specific weekdays
    generates all occurrences within 30 days with the same recurrence_group_id.
    """
    user = auth_user["user"]
    now = utc_now().replace(microsecond=0)
    # Start tomorrow
    start_time = now + timedelta(days=1)
    end_time = start_time + timedelta(hours=1)

    task_in = TaskCreate(
        title="Weekly Team Sync",
        description="Sync meeting",
        start_time=start_time,
        end_time=end_time,
        priority=TaskPriority.high,
        recurrence_type="weekly",
        recurrence_days=["sun", "wed"],
        force=True,
    )

    primary_task = RecurrenceService.create_recurring_series(
        db=db_session,
        user=user,
        task_in=task_in,
    )

    assert primary_task is not None
    assert primary_task.recurrence_group_id is not None
    assert primary_task.recurrence_type == "weekly"
    assert primary_task.is_recurrence_active is True

    # Check all materialized tasks for this group
    all_tasks = (
        db_session.query(Task)
        .filter(Task.recurrence_group_id == primary_task.recurrence_group_id)
        .order_by(Task.start_time.asc())
        .all()
    )

    # 30-day window with 2 days per week -> around 8-9 occurrences
    assert len(all_tasks) >= 4
    for t in all_tasks:
        assert t.recurrence_group_id == primary_task.recurrence_group_id
        assert t.title == "Weekly Team Sync"
        assert t.priority == "high"
        # Duration preserved
        assert (t.end_time - t.start_time) == timedelta(hours=1)
        assert t.is_recurrence_active is True


def test_finite_recurrence_by_count(client, auth_user, db_session):
    """
    Test that recurrence_count=3 limits total materialized occurrences to exactly 3.
    """
    user = auth_user["user"]
    now = utc_now().replace(microsecond=0)
    start_time = now + timedelta(days=1)
    end_time = start_time + timedelta(minutes=45)

    task_in = TaskCreate(
        title="Medication Course",
        start_time=start_time,
        end_time=end_time,
        priority=TaskPriority.urgent,
        recurrence_type="daily",
        recurrence_count=3,
        force=True,
    )

    primary_task = RecurrenceService.create_recurring_series(
        db=db_session,
        user=user,
        task_in=task_in,
    )

    all_tasks = (
        db_session.query(Task)
        .filter(Task.recurrence_group_id == primary_task.recurrence_group_id)
        .all()
    )

    assert len(all_tasks) == 3


def test_finite_recurrence_by_end_date(client, auth_user, db_session):
    """
    Test that recurrence_end_date stops generating occurrences past the cutoff date.
    """
    user = auth_user["user"]
    now = utc_now().replace(microsecond=0)
    start_time = now + timedelta(days=1)
    end_time = start_time + timedelta(hours=1)
    end_cutoff = start_time + timedelta(days=5)

    task_in = TaskCreate(
        title="5-Day Workshop",
        start_time=start_time,
        end_time=end_time,
        recurrence_type="daily",
        recurrence_end_date=end_cutoff,
        force=True,
    )

    primary_task = RecurrenceService.create_recurring_series(
        db=db_session,
        user=user,
        task_in=task_in,
    )

    all_tasks = (
        db_session.query(Task)
        .filter(Task.recurrence_group_id == primary_task.recurrence_group_id)
        .order_by(Task.start_time.asc())
        .all()
    )

    for t in all_tasks:
        t_start = t.start_time if t.start_time.tzinfo else t.start_time.replace(tzinfo=timezone.utc)
        assert t_start <= end_cutoff


def test_rolling_refill_idempotent(client, auth_user, db_session):
    """
    Test that ensure_rolling_occurrences creates zero duplicates on repeated calls.
    """
    user = auth_user["user"]
    now = utc_now().replace(microsecond=0)
    start_time = now + timedelta(days=1)
    end_time = start_time + timedelta(hours=1)

    task_in = TaskCreate(
        title="Daily Standup",
        start_time=start_time,
        end_time=end_time,
        recurrence_type="daily",
        force=True,
    )

    primary_task = RecurrenceService.create_recurring_series(
        db=db_session,
        user=user,
        task_in=task_in,
    )

    count_before = (
        db_session.query(Task)
        .filter(Task.recurrence_group_id == primary_task.recurrence_group_id)
        .count()
    )

    # Call ensure_rolling_occurrences immediately
    added_count = RecurrenceService.ensure_rolling_occurrences(db_session, user.id)
    assert added_count == 0

    count_after = (
        db_session.query(Task)
        .filter(Task.recurrence_group_id == primary_task.recurrence_group_id)
        .count()
    )
    assert count_after == count_before


def test_stop_recurring_series_endpoint(client, auth_user, db_session):
    """
    Test stopping a series sets is_recurrence_active=False, deletes future uncompleted instances,
    and preserves past/completed instances.
    """
    user = auth_user["user"]
    now = utc_now().replace(microsecond=0)
    group_id = "test-group-stop-123"

    # Past completed task
    past_task = Task(
        user_id=user.id,
        title="Gym Session",
        start_time=now - timedelta(days=2),
        end_time=now - timedelta(days=2, hours=-1),
        status=TaskStatus.completed.value,
        recurrence_type="daily",
        recurrence_group_id=group_id,
        is_recurrence_active=True,
    )
    # Future uncompleted task 1
    future_task1 = Task(
        user_id=user.id,
        title="Gym Session",
        start_time=now + timedelta(days=1),
        end_time=now + timedelta(days=1, hours=1),
        status=TaskStatus.pending.value,
        recurrence_type="daily",
        recurrence_group_id=group_id,
        is_recurrence_active=True,
    )
    # Future uncompleted task 2
    future_task2 = Task(
        user_id=user.id,
        title="Gym Session",
        start_time=now + timedelta(days=2),
        end_time=now + timedelta(days=2, hours=1),
        status=TaskStatus.pending.value,
        recurrence_type="daily",
        recurrence_group_id=group_id,
        is_recurrence_active=True,
    )
    db_session.add_all([past_task, future_task1, future_task2])
    db_session.commit()

    resp = client.post(
        f"/api/v1/tasks/recurrence/{group_id}/stop?delete_future=true",
        headers=auth_user["headers"],
    )

    assert resp.status_code == 200
    data = resp.json()
    assert data["stopped"] is True
    assert data["groupId"] == group_id
    assert data["deletedFutureCount"] == 2

    # Check database state
    remaining = (
        db_session.query(Task)
        .filter(Task.recurrence_group_id == group_id)
        .all()
    )
    # Only past task remains
    assert len(remaining) == 1
    assert remaining[0].id == past_task.id
    assert remaining[0].is_recurrence_active is False


def test_ai_tool_executor_recurring_and_stop(client, auth_user, db_session):
    """
    Test ToolExecutor creating and stopping recurring tasks through tool dispatch.
    """
    user = auth_user["user"]
    executor = ToolExecutor(db=db_session, user=user)

    now = utc_now().replace(microsecond=0)
    start_str = (now + timedelta(days=1)).isoformat()
    end_str = (now + timedelta(days=1, hours=1)).isoformat()

    # 1. Create weekly recurring task via ToolExecutor
    create_res = executor.create_task(
        title="جلسة علاج طبيعي",
        start_time=start_str,
        end_time=end_str,
        recurrence_type="weekly",
        recurrence_days=["sun", "tue"],
        recurrence_count=4,
    )

    assert create_res["status"] == "success"
    assert executor.tasks_mutated is True
    created_task = create_res["task"]
    assert created_task["recurrenceType"] == "weekly"
    group_id = created_task["recurrenceGroupId"]
    assert group_id is not None

    # Total 4 occurrences materialized
    count = db_session.query(Task).filter(Task.recurrence_group_id == group_id).count()
    assert count == 4

    # 2. Stop recurring task via ToolExecutor
    stop_res = executor.stop_recurring_task(search_query="علاج طبيعي", delete_future=True)
    assert stop_res["status"] == "success"
    assert stop_res["groupId"] == group_id
    assert "تم إيقاف تكرار" in stop_res["message"]
