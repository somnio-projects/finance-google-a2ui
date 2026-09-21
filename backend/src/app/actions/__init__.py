"""Surface actions — what a generated surface is allowed to send back.

A **framework-free** package, peer of ``app.presentation`` (spec 0022 OD-8).
It holds the action contract, the registry and the declaration a payload
publishes; it imports ``app.core`` and ``app.domain`` and nothing else.

The dependency directions that make this the right place:

* ``presentation → actions`` is pure-to-pure — a projection imports
  ``SurfaceActionRef`` to publish what it offers;
* ``services → actions`` is dispatch — the turn is started there, not here.

Putting the registry inside ``presentation`` would make a pure render package
own turn dispatch; putting it inside ``agent`` would make ``presentation``
depend on ``agent``. Importing this package is what runs every
``register(...)`` call, exactly as importing ``presentation.views`` does.
"""

from app.actions.defined import LOADED

__all__ = ["LOADED"]
