#!/usr/bin/env python3
"""Thin wrapper: ``make purge-audit`` / the monthly Cloud Run job.

The logic lives in ``app.jobs.purge_audit`` (type-checked, 100 % covered);
this file only starts the event loop.
"""

import asyncio

from app.jobs.purge_audit import main

if __name__ == "__main__":  # pragma: no cover - CLI guard
    asyncio.run(main())
