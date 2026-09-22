# 0034 — The catalog serves the gallery

- **Area:** backend (+ frontend/0016, which binds it)
- **Status:** In progress
- **Ticket:** _unassigned — no GGU number exists for this yet; none is invented here_
- **Also:** [0021](0021-machine-readable-catalog.md) (the snapshot's `fields`), [0023](0023-catalog-serves-the-client.md) (guidance, component names), [0009](0009-prompt-fragments.md) (the prompt is generated), [ADR-K](../../docs/adr/ADR-K-response-shaping.md) D-8/D-14/D-15
- **Owner:** Lautaro Bertuzzi · **Date:** 2026-09-22

## 1. Problem

The developer catalog (frontend/0016) draws two things per view that a
client could not get from `GET /v1/views`: the field inventory and the text
the system prompt carries for the view. The inventory existed only in
`docs/catalog/view-catalog.snapshot.json`, an artefact for a test to load,
and the fragment existed only inside `prompt_fragment`, joined for the whole
registry and handed to the model. A gallery that wanted either would have
transcribed it — the second declaration 0023 exists to forbid.

## 2. What ships

- `catalog_entry` — and so `GET /v1/views` and `ViewDescriptor` — carries
  **`fields`**, the rows the snapshot has held since GGU-53 (`FieldDescriptor`
  in `schemas/view_field.py`), and **`prompt`**, the lines the model is
  taught for that one view. Both are read off the projection; a new chart
  reaches them with no shared file edited (ADR-K D-15).
- `prompt.view_fragment(projection)` is the per-view half of
  `prompt_fragment`, which now joins it; the assembled prompt is byte-for-byte
  what it was.
- `published.inventory_of` / `published.field_rows` hold the one inventory
  walk both artefacts and the endpoint read; `catalog_doc.fields_of` and
  `catalog_json` call them. `_absent` (dash → `null`) moved with it.
- The snapshot gains `prompt`; its `fields` are unchanged.

## 3. Rulings

- **OD-1 — the served row is the snapshot's row.** Same keys, same `null`
  where the Markdown prints a dash (0021 AC-5), so the frontend's fixture can
  be the snapshot with `view` renamed `id` and nothing else.
- **OD-2 — the digest ignores both.** `fields` is the payload schema walked
  and `prompt` is the summary, options and guidance joined — every fact
  already hashed. Hashing the renderings too would move every frozen `v1`
  digest the day a wording changed; `catalog_doc.DERIVED_KEYS` names them
  and `digest` drops them, and `CONTRACT.md` is byte-identical after
  regeneration. A key named there that the entry stopped carrying is a
  `KeyError`, on purpose.
- **OD-3 — the Markdown contract does not print the fragment.** The
  designer's document already prints the pair the fragment is built from;
  a third rendering of it would be one more thing to keep in step.

## 4. Test decision

`test_catalog_fields.py`: the served rows equal the snapshot's and follow
the inventory's paths; `null` where the table has a dash; the entry's
`prompt` equals `view_fragment`, sits inside `prompt_fragment`, opens with
the id and summary, and matches the snapshot's; the pair appears only where
design wrote one; `DERIVED_KEYS` are all keys of the entry; `ViewDescriptor`
round-trips the rows and `FieldDescriptor`'s fields are exactly the row's
keys. The endpoint test asserts both on `/v1/views`. `make catalog` run and
both artefacts committed; 100 % branch coverage, as the gate requires.
