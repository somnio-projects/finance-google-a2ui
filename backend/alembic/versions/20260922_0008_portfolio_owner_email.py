"""key the portfolio on its owner's e-mail instead of the token subject

Revision ID: 0008
Revises: 0007
Create Date: 2026-09-22 12:00:00 UTC

Spec 0035 §4. ``portfolios.subject`` held the identity provider's opaque
``sub``: a row that named nobody, and two rows for one person who signed in
through Firebase's Google button and its e-mail button. The key becomes the
verified e-mail (``Principal.owner_key``), which is the join key the
provisioning registry already chose (spec 0027 OD-1).

**Existing rows are deleted, in both directions, on purpose.** An opaque
``sub`` cannot be mapped to an e-mail by any rule this service knows — there
is no join to attempt, and inventing one would assign somebody else's
portfolio to a real address. Keeping them instead would leave rows no caller
can ever reach. The data is simulated, `PersistentPortfolioProvider.get`
reseeds on a miss (spec 0003 OD-7), and every screen says *"Simulated
activity — resets each session."*

``portfolio_lots`` and ``portfolio_transactions`` cascade, so the delete is
one statement.
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0008"
down_revision: str | None = "0007"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

_TABLE = "portfolios"


def upgrade() -> None:
    """Replace ``subject`` with ``owner_email``, emptying the table first."""
    op.execute(sa.text(f"DELETE FROM {_TABLE}"))
    op.drop_constraint("uq_portfolios_subject", _TABLE, type_="unique")
    op.drop_index(op.f("ix_portfolios_subject"), table_name=_TABLE)
    op.drop_column(_TABLE, "subject")
    op.add_column(
        _TABLE, sa.Column("owner_email", sa.String(length=320), nullable=False)
    )
    op.create_index(
        op.f("ix_portfolios_owner_email"), _TABLE, ["owner_email"], unique=False
    )
    op.create_unique_constraint("uq_portfolios_owner_email", _TABLE, ["owner_email"])


def downgrade() -> None:
    """Restore ``subject``, emptying the table for the same reason."""
    op.execute(sa.text(f"DELETE FROM {_TABLE}"))
    op.drop_constraint("uq_portfolios_owner_email", _TABLE, type_="unique")
    op.drop_index(op.f("ix_portfolios_owner_email"), table_name=_TABLE)
    op.drop_column(_TABLE, "owner_email")
    op.add_column(_TABLE, sa.Column("subject", sa.String(length=255), nullable=False))
    op.create_index(op.f("ix_portfolios_subject"), _TABLE, ["subject"], unique=False)
    op.create_unique_constraint("uq_portfolios_subject", _TABLE, ["subject"])
