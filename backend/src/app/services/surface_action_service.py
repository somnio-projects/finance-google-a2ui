"""Resolve an inbound surface action into the turn it starts (spec 0022 §3).

The one place a `data` part becomes a prompt. It resolves the id against the
registry, validates the arguments against that action's own model, records
telemetry and writes the audit event when the action declares one — then hands
back **the sentence the backend composed**, which is all the turn ever sees.

Three properties the tests hold this to:

* **Validation happens before the stream opens.** A bad action is a clean
  JSON-RPC error rather than a stream whose first event is a failure (AC-4).
* **Rejection is terminal.** Unlike an invalid render intent, which falls back
  to the default projection because a wrong-looking chart beats no chart, an
  invalid action has no sensible default — "go deeper on <something the
  backend refused to read>" cannot be guessed, and silently running a
  different turn than the one the user tapped is worse than saying no.
* **Telemetry carries the action id and nothing else.** The id is a registered
  constant; an argument value is the user's, and the composed prompt is the
  conversation (AC-10).
"""

from typing import Final

from app.actions.registry import ACTIONS
from app.actions.resolve import composed_prompt
from app.core.errors import AppError, FeatureDisabledError
from app.core.principal import Principal
from app.core.protocols import ErrorReporter
from app.schemas.a2a_parts import ActionData
from app.services.audit_service import AuditService
from app.services.feature_flag_service import FeatureFlagService

FEATURE_KEY: Final[str] = "surface.actions"
ACCEPTED_METRIC: Final[str] = "surface.action.accepted"
REJECTED_METRIC: Final[str] = "surface.action.rejected"
AUDIT_ACTION: Final[str] = "surface_action.invoke"


class SurfaceActionService:
    """Turn a validated `data` part into the prompt one turn will run."""

    def __init__(
        self,
        *,
        flags: FeatureFlagService,
        audit: AuditService,
        reporter: ErrorReporter,
    ) -> None:
        """Bind the dispatcher to the flag gate, the audit trail and telemetry."""
        self._flags = flags
        self._audit = audit
        self._reporter = reporter

    async def enabled(self) -> bool:
        """Say whether `surface.actions` is on; dark-launched off (0022 §9)."""
        return await self._flags.is_enabled(FEATURE_KEY, default=False)

    async def prompt_for(
        self, principal: Principal, data: ActionData, *, request_id: str
    ) -> str:
        """Resolve one inbound action into the turn's input.

        Args:
            principal: The authenticated caller; the turn runs as this subject.
            data: The action id and scalar arguments the surface sent back.
            request_id: Correlation id, for the audit event when one is written.

        Returns:
            The server-composed prompt for that action and those arguments.

        Raises:
            FeatureDisabledError: While `surface.actions` is off — a disabled
                capability is one that does not exist.
            UnknownActionError: When the id is not registered.
            ValidationFailedError: When an argument is undeclared or out of
                range. The message names the argument, never its value.
        """
        if not await self.enabled():
            msg = f"feature {FEATURE_KEY!r} is disabled"
            raise FeatureDisabledError(msg)
        try:
            action = ACTIONS.get(data.action)
            prompt = composed_prompt(action, data.args)
        except AppError:
            # The tag is the id the caller *named*, which is the only thing
            # worth counting about a rejection — never an argument value.
            self._reporter.increment(REJECTED_METRIC, tags={"action": data.action})
            raise
        self._reporter.increment(ACCEPTED_METRIC, tags={"action": action.id})
        if action.audited:
            await self._audit.record(
                principal,
                action=AUDIT_ACTION,
                request_id=request_id,
                target=action.id,
            )
        return prompt


__all__ = [
    "ACCEPTED_METRIC",
    "AUDIT_ACTION",
    "FEATURE_KEY",
    "REJECTED_METRIC",
    "SurfaceActionService",
]
