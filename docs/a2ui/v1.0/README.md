# A2UI v1.0 — vendored schemas and the wire contract

The v1.0 path of this showcase (ADR-M). `frontend/` and `POST /a2a` stay on
v0.9 and do not read anything here.

| Folder | What | Owner |
|---|---|---|
| `schemas/` | The official v1.0 JSON Schemas, copied verbatim from `a2ui-project/a2ui` @ `e83e074` (`specification/v1_0/json/`, 2026-09-29), Apache-2.0. Never hand-edited; bump by re-copying and recording the new sha here. | upstream |
| `examples/` | The wire contract between `backend/` (`/a2ui/v1/a2a`) and `frontend_v1/`: one `DataPart` per file. Both suites validate or parse every file. | spec `backend/0053` |
| `finance.catalog.json` | The finance catalog, **generated** by `cd backend && make catalog` from the projection registry and gated by regeneration. | spec `backend/0053` |
