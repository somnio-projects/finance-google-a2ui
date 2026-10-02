"""SQLAlchemy ORM entities.

Import every model here so Alembic's autogenerate sees the full metadata.

That sentence was false for four of the eight tables (GGU-127, spec 0048) and
nothing was watching it. It is now held by
`tests/integration/test_metadata_completeness.py`, which compares the metadata
a fresh `import app.models` registers — the object `alembic/env.py` hands to
autogenerate as `target_metadata` — against the tables the migrations created.
"""

from app.models.audit_event import AuditEvent
from app.models.base import Base, TimestampMixin, UpdatedAtMixin
from app.models.conversation_message import ConversationMessage
from app.models.conversation_session import ConversationSession
from app.models.feature_flag import FeatureFlag
from app.models.portfolio import Portfolio, PortfolioLot, PortfolioTransaction
from app.models.user import User

__all__ = [
    "AuditEvent",
    "Base",
    "ConversationMessage",
    "ConversationSession",
    "FeatureFlag",
    "Portfolio",
    "PortfolioLot",
    "PortfolioTransaction",
    "TimestampMixin",
    "UpdatedAtMixin",
    "User",
]
