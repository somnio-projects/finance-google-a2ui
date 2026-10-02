"""widen portfolio_transactions.kind for staking_reward

Revision ID: 0009
Revises: 0008
Create Date: 2026-09-24 12:00:00 UTC

Spec 0044 OD-7, AC-6. The portfolio became crypto and the income kind became
``staking_reward`` — fourteen characters, against a column sized ``String(8)``
because ``dividend`` was exactly eight. The seed would have been rejected on
write, which is the whole of the schema change.

**No data is migrated, and that is the ruling, not an omission** (spec 0044
OD-9). Every row in these tables is demo data by construction, so the
portfolios are *regenerated* — ``python -m app.jobs.seed_portfolios --reset
<emails>`` replaces each owner's lots and ledger with the crypto seed. A
backfill of ``'dividend'`` to ``'staking_reward'`` would preserve rows whose
symbols no longer exist in the market reference, which is a worse state than
having none.
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0009"
down_revision: str | None = "0008"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.alter_column(
        "portfolio_transactions",
        "kind",
        existing_type=sa.String(length=8),
        type_=sa.String(length=16),
        existing_nullable=False,
    )


def downgrade() -> None:
    op.alter_column(
        "portfolio_transactions",
        "kind",
        existing_type=sa.String(length=16),
        type_=sa.String(length=8),
        existing_nullable=False,
    )
