"""add_recurring_tasks_fields

Revision ID: ee4dbc9f83f3
Revises: d9f27b5333a1
Create Date: 2026-11-22 19:19:20.330641

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'ee4dbc9f83f3'
down_revision: Union[str, Sequence[str], None] = 'd9f27b5333a1'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    with op.batch_alter_table("tasks", schema=None) as batch_op:
        batch_op.add_column(sa.Column("recurrence_type", sa.String(length=20), server_default="none", nullable=False))
        batch_op.add_column(sa.Column("recurrence_days", sa.String(length=50), nullable=True))
        batch_op.add_column(sa.Column("recurrence_end_date", sa.DateTime(timezone=True), nullable=True))
        batch_op.add_column(sa.Column("recurrence_count", sa.Integer(), nullable=True))
        batch_op.add_column(sa.Column("recurrence_group_id", sa.String(length=64), nullable=True))
        batch_op.add_column(sa.Column("is_recurrence_active", sa.Boolean(), server_default="true", nullable=False))
        batch_op.create_index("ix_tasks_recurrence_group_id", ["recurrence_group_id"], unique=False)


def downgrade() -> None:
    """Downgrade schema."""
    with op.batch_alter_table("tasks", schema=None) as batch_op:
        batch_op.drop_index("ix_tasks_recurrence_group_id")
        batch_op.drop_column("is_recurrence_active")
        batch_op.drop_column("recurrence_group_id")
        batch_op.drop_column("recurrence_count")
        batch_op.drop_column("recurrence_end_date")
        batch_op.drop_column("recurrence_days")
        batch_op.drop_column("recurrence_type")
