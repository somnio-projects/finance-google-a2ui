"""Scheduled maintenance jobs (retention, housekeeping).

Each job is a small async function over the ``Container`` so it is wired from
the same composition root as the API and tested like any other module. The
``scripts/`` wrappers only parse the environment and call ``main``.
"""
