"""create portfolios, lots and transactions

Revision ID: 0005
Revises: 0004
Create Date: 2026-09-20 00:00:00 UTC

Spec 0020. The portfolio leaves process memory because dev now runs more than
one instance (``min_instances = 1, max_instances = 2``), and two in-process
caches meant one subject had two portfolios with two different ``as_of``.

``uq_portfolios_subject`` is the load-bearing constraint: two instances seeding
the same new subject converge on one row, the loser catching the integrity
error and re-reading. Without it the race silently produces two portfolios.

Money and quantity are ``NUMERIC(38, 18)`` — exact, never float (ADR-E D-5).

Holdings are **not** a table. ``Portfolio.positions`` is derived from the lots
and ``Portfolio.validate`` proves it; storing the derivation would let the two
drift apart.
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "0005"
down_revision: str | None = "0004"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

EXACT = sa.Numeric(38, 18)


def _timestamps() -> list[sa.Column[sa.DateTime]]:
    """Return the created/updated pair every table in this schema carries."""
    return [
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
    ]


def upgrade() -> None:
    op.create_table(
        "portfolios",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("subject", sa.String(length=255), nullable=False),
        sa.Column("as_of", sa.DateTime(timezone=True), nullable=False),
        *_timestamps(),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_portfolios")),
        sa.UniqueConstraint("subject", name="uq_portfolios_subject"),
    )
    op.create_index("ix_portfolios_subject", "portfolios", ["subject"])

    op.create_table(
        "portfolio_lots",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("portfolio_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("lot_id", sa.String(length=32), nullable=False),
        sa.Column("symbol", sa.String(length=10), nullable=False),
        sa.Column("acquired_on", sa.Date(), nullable=False),
        sa.Column("quantity", EXACT, nullable=False),
        sa.Column("cost_basis", EXACT, nullable=False),
        *_timestamps(),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_portfolio_lots")),
        sa.ForeignKeyConstraint(
            ["portfolio_id"],
            ["portfolios.id"],
            name=op.f("fk_portfolio_lots_portfolio_id_portfolios"),
            ondelete="CASCADE",
        ),
    )
    op.create_index("ix_portfolio_lots_portfolio_id", "portfolio_lots", ["portfolio_id"])

    op.create_table(
        "portfolio_transactions",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("portfolio_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("transaction_id", sa.String(length=32), nullable=False),
        sa.Column("occurred_on", sa.Date(), nullable=False),
        sa.Column("kind", sa.String(length=8), nullable=False),
        sa.Column("symbol", sa.String(length=10), nullable=False),
        sa.Column("quantity", EXACT, nullable=False),
        sa.Column("price", EXACT, nullable=False),
        sa.Column("amount", EXACT, nullable=False),
        *_timestamps(),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_portfolio_transactions")),
        sa.ForeignKeyConstraint(
            ["portfolio_id"],
            ["portfolios.id"],
            name=op.f("fk_portfolio_transactions_portfolio_id_portfolios"),
            ondelete="CASCADE",
        ),
    )
    op.create_index(
        "ix_portfolio_transactions_portfolio_id",
        "portfolio_transactions",
        ["portfolio_id"],
    )


def downgrade() -> None:
    op.drop_table("portfolio_transactions")
    op.drop_table("portfolio_lots")
    op.drop_table("portfolios")
