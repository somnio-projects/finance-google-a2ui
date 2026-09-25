"""What autogenerate sees, against what the migrations built (spec 0048).

GGU-127: `app/models/__init__.py` opened with *"Import every model here so
Alembic's autogenerate sees the full metadata"* and imported four of the eight
mapped tables. `alembic/env.py` hands that object to autogenerate as
`target_metadata`, and a table in the database that is absent from the metadata
reads as **deleted**, so `alembic revision --autogenerate` emitted
`op.drop_table()` for `portfolios`, `portfolio_lots`, `portfolio_transactions`
and `users` — a plausible-looking revision that destroys the demo data, and on
a `backend-cd` run it executes against dev before traffic shifts.

Two things this file deliberately does **not** do:

- **It holds no list of table names.** A literal set of eight would be the same
  unenforced claim one level down — green until somebody adds a ninth model
  *and* remembers to edit it. Both tests compare against the schema the
  migrations actually created, so a ninth table is covered the day its
  migration lands rather than the day somebody remembers this file.
- **It does not read `Base.metadata` in this process.** By the time pytest has
  collected the suite, `app.models.portfolio` and `app.models.user` have been
  imported by the repositories that use them, and the registry holds all eight
  tables *whatever* `models/__init__.py` says: measured on the broken tree, an
  in-process assertion is **green**. The table set is therefore measured in a
  fresh interpreter that imports exactly what `alembic/env.py` imports, which
  is the only process whose registry answers the question that was asked.

  The second test is in-process on purpose, and it is sound there for the
  opposite reason: importing a module can only *add* tables, never add or drop
  a column, so column-level drift is the same in either process. That half was
  not hypothetical either — with the imports fixed and nothing else, the four
  `drop_table` calls became three `op.drop_column('…', 'updated_at')`.
"""

import json
import subprocess
import sys
from pathlib import Path

import pytest
from alembic.autogenerate import compare_metadata
from alembic.migration import MigrationContext
from sqlalchemy import Connection, MetaData
from sqlalchemy.ext.asyncio import AsyncEngine

from app.models import Base
from tests.integration.database_cleanup import emptiable_tables

pytestmark = pytest.mark.integration

#: `alembic/env.py` does `from app.models import Base` and nothing else, so this
#: is the whole of the import that decides what autogenerate can see.
AS_ALEMBIC_SEES_IT = (
    "import json, app.models; "
    "print(json.dumps(sorted(app.models.Base.metadata.tables)))"
)

SRC = Path(__file__).parents[2] / "src"


def tables_a_fresh_import_registers() -> frozenset[str]:
    """Return the tables `import app.models` puts on `Base.metadata`.

    Returns:
        The table names autogenerate would compare the database against.
    """
    completed = subprocess.run(  # noqa: S603 - fixed argv, no shell, no caller input
        [sys.executable, "-c", AS_ALEMBIC_SEES_IT],
        capture_output=True,
        text=True,
        check=False,
        env={"PYTHONPATH": str(SRC)},
    )
    assert completed.returncode == 0, completed.stderr
    return frozenset(json.loads(completed.stdout))


async def migrated_tables(engine: AsyncEngine) -> frozenset[str]:
    """Return the tables Alembic has really created, read back by reflection.

    Args:
        engine: An engine bound to the migrated test database.

    Returns:
        Every reflected table except Alembic's own bookkeeping.
    """
    reflected = MetaData()
    async with engine.begin() as connection:
        await connection.run_sync(reflected.reflect)
    # `emptiable_tables` drops `alembic_version` and refuses a database too
    # small to be migrated, so an equality of two empty sets cannot pass here.
    return frozenset(table.name for table in emptiable_tables(reflected))


async def test_the_metadata_autogenerate_reads_holds_every_migrated_table(
    engine: AsyncEngine,
) -> None:
    """AC-1/AC-2: `target_metadata` and the migrated schema name the same tables."""
    migrated = await migrated_tables(engine)

    declared = tables_a_fresh_import_registers()

    assert declared == migrated, (
        "`alembic revision --autogenerate` would propose dropping "
        f"{sorted(migrated - declared)} and creating {sorted(declared - migrated)}. "
        f"A fresh `import app.models` registers {sorted(declared)}; the migrations "
        f"created {sorted(migrated)}. Import every model in "
        "src/app/models/__init__.py (GGU-127)."
    )


def _schema_differences(connection: Connection) -> list[object]:
    """Return alembic's own diff between the live schema and the metadata."""
    context = MigrationContext.configure(connection, opts={"compare_type": True})
    return compare_metadata(context, Base.metadata)


async def test_autogenerating_against_the_migrated_schema_finds_nothing_to_change(
    engine: AsyncEngine,
) -> None:
    """AC-4: the revision `--autogenerate` would write is empty, asserted not pasted.

    The columns half of the same defect: three tables carry `updated_at` in
    PostgreSQL and carried it in no model, so autogenerate proposed dropping it.
    """
    async with engine.connect() as connection:
        differences = await connection.run_sync(_schema_differences)

    assert differences == [], (
        "autogenerate would write a non-empty revision: "
        f"{differences}. Either the models are missing what the migrations "
        "created, or a schema change landed with no revision (GGU-127)."
    )
