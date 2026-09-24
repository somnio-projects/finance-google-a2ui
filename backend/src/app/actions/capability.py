"""Whether surface actions are *shipped*, in one place (spec 0022 §9).

Two things read this, and they must not drift:

* ``SurfaceActionService`` passes it as the flag's **default**, so execution is
  refused while it is off;
* a projection decides whether to **declare** an action at all.

Both matter, because they answer different questions and a reader keeps
conflating them. The flag gates *execution*. The declaration is the
*contract*: it reaches the payload, the A2UI props, ``GET /v1/views`` and the
frozen ``docs/catalog/CONTRACT.md`` — which #45 and #48 hand to the client as
a machine-readable artefact. Declaring an action while the capability is off
would publish an affordance that answers ``-32601`` to anyone who binds to the
catalogue and taps it. A footnote cannot reach a machine-readable document, so
the declaration is gated instead of annotated.

**The skew is deliberately one-directional.** Turning the flag on at runtime
through the admin API without flipping this constant means execution works and
nothing advertises it — safe. The reverse, advertising more than the service
will do, is the defect. A static artefact cannot track a dynamic flag, so it
errs towards claiming less.

Flipping this to ``True`` (spec 0029 OD-3) made the declaration appear
everywhere at once, ``make catalog`` regenerate, and the gate fail until the
contract was committed.
"""

from typing import Final

#: The flag key, so the service and the tests spell it once.
FEATURE_KEY: Final[str] = "surface.actions"

#: What the capability resolves to as shipped. On since spec 0029: the client
#: sends `data` parts (frontend/0011) and the turn recommends its chips.
SHIPPED_ENABLED: Final[bool] = True

__all__ = ["FEATURE_KEY", "SHIPPED_ENABLED"]
