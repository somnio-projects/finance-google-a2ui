"""create users — the provisioning registry

Revision ID: 0006
Revises: 0005
Create Date: 2026-09-21 00:00:00 UTC

Spec 0027. Sign-in is invite-only: an identity provider proves who a caller
is, and this table says whether that person may use the preview. It is keyed
by the lower-cased e-mail because it is the one claim every provider carries
and the one thing an inviter knows before the invitee has ever signed in.

``uq_users_email`` is the load-bearing constraint; the two CHECKs keep the
role and status vocabularies in the database as well as in pydantic, because
the database is the last line of defence and migrations are the only schema
path.
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "0006"
down_revision: str | None = "0005"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "users",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("email", sa.String(length=320), nullable=False),
        sa.Column("display_name", sa.String(length=120), nullable=True),
        sa.Column("role", sa.String(length=16), nullable=False),
        sa.Column("status", sa.String(length=16), nullable=False),
        sa.Column("invited_by", sa.String(length=320), nullable=True),
        sa.Column("last_seen_at", sa.DateTime(timezone=True), nullable=True),
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
        sa.CheckConstraint(
            "role IN ('member', 'admin')", name=op.f("ck_users_role_allowed")
        ),
        sa.CheckConstraint(
            "status IN ('requested', 'invited', 'active', 'revoked')",
            name=op.f("ck_users_status_allowed"),
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_users")),
        sa.UniqueConstraint("email", name=op.f("uq_users_email")),
    )


def downgrade() -> None:
    op.drop_table("users")
