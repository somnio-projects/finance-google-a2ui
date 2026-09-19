"""add audit_events.target

Revision ID: 0003
Revises: 0002
Create Date: 2026-09-19 00:00:00 UTC

``action`` keeps the ``<domain>.<verb>`` shape (String(64)); the subject of the
action — a feature-flag key up to 100 chars, a resource id — moves to ``target``.
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0003"
down_revision: str | None = "0002"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "audit_events", sa.Column("target", sa.String(length=255), nullable=True)
    )


def downgrade() -> None:
    op.drop_column("audit_events", "target")
