"""add memo to portfolio_transactions

Revision ID: 0007
Revises: 0006
Create Date: 2026-09-21 12:00:00 UTC

Spec 0028. The Activity tab prints a line of words beside a row — *Bank
transfer · Chase ••4021*, *qualified* — that no figure carries. They are
server-written (N-9) and therefore stored with the row, nullable because a
plain trade has none.
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0007"
down_revision: str | None = "0006"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "portfolio_transactions",
        sa.Column("memo", sa.String(length=64), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("portfolio_transactions", "memo")
