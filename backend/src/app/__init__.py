"""finance-a2ui backend package.

Layering (dependencies point inward only):

    api  ->  services  ->  repositories  ->  models
     |          |
     v          v
   schemas    core (settings, errors, protocols)   <-  infra / auth (adapters)

`app.bootstrap.create_app` is the single composition root.
"""

__all__ = ["__version__"]

__version__ = "0.1.0"
