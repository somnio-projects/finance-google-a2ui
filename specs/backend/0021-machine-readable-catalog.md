# 0021 — The catalog contract, also as JSON the client can load

- **Area:** backend
- **Status:** Implemented
- **Ticket:** [GGU-53](https://somniosoftware.atlassian.net/browse/GGU-53) (server half) · **Related:** 0019 (frozen catalog contract), 0005 (presentation layer), [ADR-K](../../docs/adr/ADR-K-response-shaping.md)
- **Owner:** Lautaro Bertuzzi · **Date:** 2026-09-20

## 1. Problem

Spec 0019 freezes the component contract by **generating** it:
`docs/catalog/CONTRACT.md` is rendered from the projection registry and the
ship gate re-renders and diffs it, so a projection cannot move without the
document moving in the same commit.

That artefact is Markdown, and Markdown is for people. The client half of
GGU-53 needs the same facts in a form a **test** can load: the Flutter
`catalog_contract_test.dart` asserts that every view the backend serves has a
registered `FinanceCatalog` item, that no client component is invented, and
that each shipped example deserialises into its widget's model. A Dart test
cannot parse a table of prose.

The ticket names the drift this closes, and it is not hypothetical: the
backend emits `Surface(component="WaterfallChart")` and `"DonutChart"`, while
the component tickets were written against `attribution_waterfall` and
`holdings_summary`. Nothing in the repository compares the two, because
nothing publishes the component names in a form that can be compared.

So: **one more rendering of the same registry read**, not a second source of
truth. A JSON file someone hand-maintains would drift exactly like the
transcription 0019 refused to write.

## 2. Scope

**In**

- `app/presentation/catalog_json.py` — the JSON rendering: per view the
  component type, the view id, the digest, the DTO field paths, the options
  schema and the rendered example.
- `app/presentation/catalog_artifacts.py` — the list of generated artefacts
  and one render pass over the registry that produces all of them.
- `docs/catalog/view-catalog.snapshot.json` — the generated artefact.
- `backend/scripts/generate_catalog_contract.py` — now writes and `--check`s
  **every** artefact in that list, reporting each one.
- `app/presentation/catalog_legend.py` — the second half of the contract's
  human-written prose, split out of `catalog_preamble.py` when the new
  cross-reference paragraph pushed it past the 150-line budget.
- `make catalog` / `make catalog-check`, the CI Quality step and the
  pre-commit hook, which cover both artefacts through the same command.
- `tests/unit/presentation/test_catalog_snapshot.py`.

**Out**

- **The Flutter half of GGU-53** — the test harness (`pump_app.dart`, the
  golden policy) and `catalog_contract_test.dart` itself. This spec ships the
  artefact they consume and the server-side gate; the client end lands with
  GGU-13's `FinanceCatalog` (OD-2).
- **Any change to a projection.** Nothing here reshapes a payload, renames a
  component or adds a field. The six components the snapshot carries —
  `ComparisonCard`, `DonutChart`, `LineChart`, `OrderTicket`, `TaxLotTable`,
  `WaterfallChart` — are read from the adapters exactly as they already are.
- **The A2UI wire format** (pending ADR-L) and the gallery page (GGU-22).

## 3. What the artefact says

`docs/catalog/view-catalog.snapshot.json` is one object: a `$comment` saying
it is generated and how to regenerate it, a `version` for the document shape,
a `source`, and `views` — one entry per registered projection, ordered by id:

| Key | From |
|---|---|
| `view` | the projection's versioned id |
| `component` | its **own A2UI adapter**, asked for the shipped example |
| `digest` | the same 12-character digest the Markdown prints (0019 AC-5) |
| `summary`, `payload_type`, `endpoints` | the projection |
| `fields` | the inventory the Markdown table prints — path, type, presence, binding, state, input |
| `options_schema` | the options model's JSON schema |
| `example` | the payload rendered over the fixed sample portfolio |

`component` is **never transcribed**: `component_of` validates the shipped
example back into the payload DTO and hands it to the projection's adapter.
The name the file carries is therefore the name the backend emits, and the
round trip proves the example still deserialises — the property the Flutter
test asserts, asserted here first.

Keys are sorted and `example` is the fixed-`as_of` render, so the bytes depend
on the registry and on nothing else.

## 4. How it is enforced

Two renderings, **one** render pass, one gate:

```
ARTIFACTS = (CONTRACT.md → contract_document, view-catalog.snapshot.json → snapshot_document)
```

`render_all(REGISTRY.all())` produces both; the script writes or diffs each and
prints the fix command per artefact; `make catalog-check` (in `make gate`,
`.claude/ship-gate.json` as `py.catalog`, the CI Quality job and pre-commit)
is unchanged as a *command* and now covers both files.

The suite gates it a second time, which is what GGU-53 asks for:
`test_snapshot_matches_the_registry` regenerates in memory and compares to the
committed file, so a projection that moves without `make catalog` turns
`make gate` red in `test` as well as in `catalog-check`.

## 5. Security notes

No route, no dependency, no I/O in the presentation layer, no secret. The
snapshot contains only the seeded demo portfolio already published in the
OpenAPI examples, in `GET /v1/views` and in `CONTRACT.md` — no customer data
and no identifier. The generator writes two files inside the repository.

## 6. Acceptance criteria

- **AC-1** — `docs/catalog/view-catalog.snapshot.json` is generated from the
  registry and carries **every** registered projection, with no list of ids,
  no count and no view module imported by the generator.
- **AC-2** — Each entry carries the component type, the view id, the DTO field
  paths, the options schema and a rendered example (the ticket's list), plus
  the digest that ties it to the Markdown contract.
- **AC-3** — The component name is read from the projection's own A2UI adapter
  and appears verbatim (`DonutChart`, not `donut_chart`), because the Flutter
  `FinanceCatalog` registers against that exact string.
- **AC-4** — Every shipped example deserialises into its payload DTO and its
  adapter yields the entry's component.
- **AC-5** — Both artefacts come from **one** render pass over the registry
  and one gate command; a stale artefact fails with the diff and
  `cd backend && make catalog`, and a missing artefact is drift, not a pass.
- **AC-6** — A projection that changes without regeneration fails
  `make gate` **twice**: in `catalog-check` and in the unit suite.
- **AC-7** — The snapshot is one JSON document, key-sorted, ending in exactly
  one newline, and states in `$comment` that it is generated.

## 7. Test plan

All unit; nothing here touches the database or the network.
`tests/unit/presentation/test_catalog_snapshot.py`:

| Test | ACs |
|---|---|
| `test_snapshot_matches_the_registry` | AC-1, AC-5, AC-6 |
| `test_every_registered_view_declares_a_client_component` | AC-1, AC-3 |
| `test_the_snapshot_names_the_component_the_backend_emits_verbatim` | AC-3 |
| `test_the_snapshot_carries_every_field_path_of_the_payload` | AC-2 |
| `test_the_shipped_example_deserialises_into_its_payload_type` | AC-4 |
| `test_the_snapshot_is_one_json_document_ending_in_a_single_newline` | AC-7 |
| `test_a_field_that_drives_nothing_reads_null_rather_than_an_em_dash` | AC-2 |
| `test_a_moved_projection_makes_the_snapshot_drift` | AC-5 |
| `test_a_missing_snapshot_is_drift_rather_than_a_pass` | AC-5 |
| `test_both_catalog_artifacts_come_from_one_render_pass` | AC-5 |

and one test added to `test_catalog_doc.py`, so the double gate is symmetric:
`test_contract_matches_the_registry` compares the **committed** Markdown with
the registry the way the snapshot's test does (AC-6). Without it the Markdown
was gated only by the script, so a generator that stopped reporting one
artefact — the `all(outcomes)` in `main` becoming an `any` — would have let a
stale `CONTRACT.md` through every check while the JSON stayed honest. Proven by
hand-editing one line of `docs/catalog/CONTRACT.md`:

```
E   AssertionError: docs/catalog/CONTRACT.md is stale — a projection moved.
    Regenerate it: cd backend && make catalog
1 failed, 8 passed in 0.22s
```

Mutation checks required: **yes** — the whole point of the artefact is a
property nothing enforced before.

**Test decision.** The failure this prevents is a component name that moves on
the server while the client keeps registering the old one, so the mutation is
exactly that: `views/holdings_allocation.py` was edited to emit
`component="PieChart"` instead of `"DonutChart"`, with no other change.

```
FAILED tests/unit/presentation/test_catalog_snapshot.py::test_snapshot_matches_the_registry
FAILED tests/unit/presentation/test_catalog_snapshot.py::test_every_registered_view_declares_a_client_component
FAILED tests/unit/presentation/test_catalog_snapshot.py::test_the_shipped_example_deserialises_into_its_payload_type
3 failed, 6 passed in 0.24s

E   AssertionError: docs/catalog/view-catalog.snapshot.json is stale — a
    projection moved. Regenerate it: cd backend && make catalog
```

`make catalog-check` went red on the same mutation, and printed the line that
matters most:

```
docs/catalog/CONTRACT.md is current (6 projections)
-      "component": "DonutChart",
+      "component": "PieChart",
docs/catalog/view-catalog.snapshot.json is stale — a projection changed.
```

The **Markdown contract stayed green**. A renamed component is invisible to
the designer-facing document — it prints payload fields, not the A2UI
adapter's output — so before this snapshot existed, the one fact the Flutter
catalog binds to was the one fact no gate checked. That is the gap GGU-53
names, reproduced and then closed. The file was restored from git and the
suite is green again (350 passed).

## 8. Open decisions

| # | Question | Owner | Resolution |
|---|---|---|---|
| OD-1 | A second script and a second gate step for the JSON, or one generator that emits both? | TL — **one generator, one gate** | Two scripts would be two lists of projections to keep in step, and the gate would grow a step every time an artefact is added. `ARTIFACTS` makes a rendering a one-line entry: the script, the Makefile target, `ship-gate.json`, the CI step and the pre-commit hook all stay exactly as they are. `ship-gate.json` is therefore **unchanged** — the command it names already covers both files, and `.claude/rules/ci-conventions.md` §5 asks for the command to match verbatim, which it does. |
| OD-2 | The ticket sequences the server end "with the first backend projection ticket (GGU-50 or GGU-52)"; all six projections already exist. | TL — **land it now, alone** | The sequencing exists so the snapshot precedes anything that could drift from it. Six projections have already shipped and one of them has already drifted from the component tickets, so the snapshot is late rather than early. Landing it on its own keeps the Flutter harness (blocked by GGU-1) from blocking the artefact its test needs. |
| OD-3 | Should a test assert the six component names, so "the JSON carries `DonutChart` verbatim" is enforced? | TL — **one named case, never the list** | Asserting all six would reintroduce the hardcoded inventory of components that 0019 OD-2 removed, and would fail the day a seventh projection registers. The suite instead asserts the *rule* over the whole registry — the snapshot's component equals what the adapter emits, and it is a `PascalCase` identifier — plus **one** named case (`holdings.allocation.v1 → DonutChart`) that pins the verbatim-naming property the client depends on. The same shape the rest of the presentation suite uses. |
| OD-4 | `fields` as bare paths (the ticket's wording) or as the full inventory row? | TL — **the full row** | The generator already computes presence, binding, state and input for the Markdown table, so carrying them costs nothing and makes the JSON a superset of the ticket's ask. The client test reads `path`; a future gallery (GGU-22) reads the rest rather than re-deriving it from a schema. Dropping to bare paths later is a shape change with a version bump; adding fields to an artefact nobody consumes yet is free. |
| OD-5 | The Markdown prints `—` where a field drives no state and takes no input. Does the JSON carry the dash? | TL — **`null`, and only in the JSON** | A dash reads well in a table and is a trap in JSON: a client would compare against a punctuation mark to learn that a field is read-only. `_absent` maps the placeholder to `null` in the snapshot only, which is what "rendered for a machine" means — the same fact, told the way each reader can act on it. `test_a_field_that_drives_nothing_reads_null_rather_than_an_em_dash` pins it from both sides: read-only fields are `null`, and `order.ticket.v1` still reports its editable ones. |
| OD-6 | `snapshot_entry` lists `summary`, `endpoints`, `options_schema` and `example`, which `contract.py::catalog_entry` already assembles for `GET /v1/views` (keyed `id`) and `catalog_doc._section` a third way. A third occurrence is normally a refactor (`api-design.md` §3). | TL — **deliberately independent** | The two answer to different masters. The snapshot is **frozen** — its shape is pinned by a digest a client binds to — while `/v1/views` is an HTTP contract that may gain a field, paginate or change its keys under `/v2`. Sharing one builder would make every HTTP change a contract change, and a frozen artefact that moves because a route moved is precisely the drift this file exists to detect. What they *do* share is the thing that must not diverge: the projection itself, and `catalog_doc.digest`. Recorded here rather than left as an unexplained duplication. |
| OD-7 | `catalog_preamble.py` went over the 150-line budget when the cross-reference paragraph was added. | TL — **split the prose, never the budget** | The legend moved to `catalog_legend.py`, at the natural seam: the preamble answers "what is frozen and who enforces it", the legend answers "how do I read a row". Raising the budget for prose would be lowering a team threshold in a feature PR. The generated document is byte-identical apart from the new paragraph. |
