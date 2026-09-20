# 0019 — The frozen catalog contract, generated from the registry

- **Area:** backend
- **Status:** Implemented
- **Ticket:** [GGU-41](https://somniosoftware.atlassian.net/browse/GGU-41) · **Related:** 0005 (presentation layer), 0009 (prompt fragments), [ADR-K](../../docs/adr/ADR-K-response-shaping.md), [ADR-E](../../docs/adr/ADR-E-money-representation.md)
- **Owner:** Lautaro Bertuzzi · **Date:** 2026-09-19

## 1. Problem

GGU-41 exists to stop one specific waste: a designer drawing against a
component schema that later renames a field, adds a required one or drops one,
after which the Figma work, the token mapping and the prompt that injects those
schemas all need rework. Its answer is to **freeze** the six component schemas
up front, and to write down, per component, every field the widget receives —
its format, whether it is required, whether it arrives pre-formatted, which UI
state it drives and whether it is an input.

The ticket then says how: transcribe the schemas from Epic 2 (GGU-16..22) by
hand into a "Schema Contract" page, and record a version identifier per
component so drift is detectable.

Two things have changed since it was written, and both change the method
rather than the goal.

**The schemas moved.** GGU-16..22 do not exist in this repository. Under
[ADR-K](../../docs/adr/ADR-K-response-shaping.md) — accepted after GGU-41 was
filed, and flagged on the ticket itself — the component schema contract *is*
the projection registry: a projection is a versioned id, a bounded options
model, a payload DTO and a pure render, registered from its own module, and
D-14 already makes one registration publish to four consumers (OpenAPI, the
`GET /v1/views` catalog, the prompt fragments and the A2UI adapter). D-9 says
the `v1` ids map 1:1 to the schemas GGU-41 freezes.

**So a hand-transcription would be a second source of truth** — and the second
source is the one that goes stale, which is the exact failure GGU-41 was
written to prevent. A table someone copied out of a DTO is correct on the day
it is written and silently wrong on the day a field is renamed, with nothing
between the two.

This spec therefore **generates** the frozen contract from the registry, and
makes the ship gate fail when the generated file and the registry disagree.

## 2. Scope

**In**

- `app/presentation/schema_facts.py` — the classification rules, one per
  column, each reading a JSON-schema node and nothing else.
- `app/presentation/inventory.py` — the walk that flattens a payload schema
  into one row per bindable field, `$refs` and lists included.
- `app/presentation/catalog_tables.py` — the Markdown tables, plus the
  options → Input mapping that expresses interactivity.
- `app/presentation/catalog_preamble.py` — the one human-written part of the
  document: what "frozen" means and how every column is derived.
- `app/presentation/catalog_doc.py` — assembly, the per-projection digest and
  the drift diff.
- `backend/scripts/generate_catalog_contract.py` — the only piece that touches
  the disk: write the file, or `--check` it and fail with the fix command.
- `docs/catalog/CONTRACT.md` — the generated artefact, checked in.
- `make catalog` / `make catalog-check`, wired into `make gate`,
  `.claude/ship-gate.json`, `backend-ci.yaml` and `.pre-commit-config.yaml`.
- Tests for all of the above, including the failure path of the gate.

**Out**

- **The six projections themselves.** `tax_lots.table.v1`, `payoff.curve.v1`,
  `scenario.comparison.v1` and `order.ticket.v1` are their own tickets, landing
  in parallel. Nothing here names them, imports them or counts them (OD-2).
- **The Figma page.** The contract is the input to it; drawing it is design's
  half of GGU-41 and is not a repository deliverable.
- **Any change to a projection.** This spec reads the registry; it does not
  reshape a payload, add a field or touch a view module.
- **A second money format, a second options vocabulary, a second registry.**
  Everything here is derived.

## 3. What the document says

`docs/catalog/CONTRACT.md` opens with the normative preamble, then an index of
every registered projection, then one section per projection:

| Part | Contents |
|---|---|
| Header | frozen id, **digest**, payload type name, serving endpoints, editable fields |
| Options | option · type/format · accepts · default · description |
| Field inventory | field · type/format · presence · binding · state · input |
| Example | the rendered payload, from the fixed sample portfolio |

**The digest** is the frozen version identifier the ticket asks for. It is the
first 12 hex characters of a sha256 over the projection's id, summary,
endpoints, options schema, payload schema and rendered example. The versioned
id names the contract; the digest proves it has not moved. A `v1` whose digest
changed is a broken freeze, visible as a one-line diff.

**Binding** answers "does this arrive pre-formatted?", and it is derived
structurally rather than from a field name: a string leaf whose containing
object also declares a numeric leaf is the pre-formatted half of an ADR-E D-2
pair (`{amount, display}`, `{value, display}`) and is classified `display`;
every other string is `text`, also bound verbatim; numeric leaves are `raw`,
for a chart's geometry and never printed. The `*Display` naming convention is
what the rule *describes*, not what it *reads*, and the document says so.

**Input** answers "is this field interactive, and within what bounds?" — the
question `order.ticket.v1` will be the first to need. Under ADR-K D-3 the only
thing a caller may send back is a **declared option**, so an editable field is
a payload field whose name matches an option of the same projection: the widget
shows it, the user edits it, the client re-requests the same view with that
option set, and the option's own bounds are the validation. A projection with
no such match is read-only, which is the honest answer for the two registered
today. See OD-3 for what this asks of `order.ticket.v1`.

## 4. How "frozen" is enforced

`make catalog-check` renders the document from the live registry, diffs it
against the checked-in file, and on any difference prints the unified diff, the
reason, and `cd backend && make catalog`. It runs in `make gate` (between
`budget` and `quality`), in `.claude/ship-gate.json` as `py.catalog`, in the
`Quality` job of `backend-ci.yaml`, and in pre-commit on any change under
`backend/src/app/presentation/`, to the generator, or to `docs/catalog/`.

Frozen therefore means **drift is detected**, not that a human promised not to
change a field. A projection cannot move without this file moving in the same
commit, and a hand-edit of the document is rejected on the next run.

## 5. Security notes

No new route, no new dependency, no I/O in the presentation layer, no secret.
The generator reads the registry and writes one Markdown file inside the
repository. `docs/catalog/CONTRACT.md` contains only the seeded demo portfolio
already published in OpenAPI examples and in `GET /v1/views` — no customer
data, no identifier, nothing that is not already public in this open-source
repository.

## 6. Acceptance criteria

- **AC-1** — `docs/catalog/CONTRACT.md` is generated from the registry, with a
  section for **every** registered projection and no hardcoded list of ids.
  A projection registered by another module appears with nothing here edited.
- **AC-2** — Every inventory column is derived from the JSON schema: type and
  bound, presence, binding, state. Each rule is pinned by its own test.
- **AC-3** — The inventory flattens nested objects and lists, resolves `$ref`,
  and stops before a self-referencing schema runs away.
- **AC-4** — A payload field named after a declared option is reported as an
  input with that option's bounds; a projection with no match is reported
  `read-only` rather than blank.
- **AC-5** — Each projection carries a stable 12-character digest over its
  whole promise; two projections never share one.
- **AC-6** — The digest moves when anything inside a frozen `v1` moves,
  including a change the printed tables do not show (a field description).
- **AC-7** — A stale document **fails** `make gate` with the diff and the
  command that fixes it. A missing document is drift, not a pass.
- **AC-8** — Free prose in a projection's description cannot break the Markdown
  table it is printed in.
- **AC-9** — `.claude/ship-gate.json`, `backend/Makefile` and
  `.github/workflows/backend-ci.yaml` carry the same check
  (`.claude/rules/ci-conventions.md` §5), and `.pre-commit-config.yaml` runs it
  first (§1).

## 7. Test plan

All unit; nothing here touches the database or the network.

| Test | ACs |
|---|---|
| `tests/unit/presentation/test_schema_facts.py` — type, bound, union and `Decimal` shapes, one hand-written fragment per case | AC-2 |
| `tests/unit/presentation/test_schema_roles.py` — presence, binding and state; the two string cases are the **same** fragment and differ only in what sits beside them | AC-2 |
| `tests/unit/presentation/test_inventory.py` — the walk over the real `attribution.waterfall.v1` schema, the option-name input rule, the depth guard, and a render whose top-level keys match the inventory | AC-3, AC-4 |
| `tests/unit/presentation/test_catalog_tables.py` — cell escaping, table shape, the no-options line, the options → Input mapping | AC-4, AC-8 |
| `tests/unit/presentation/test_catalog_doc.py` — coverage of every registered projection, digest properties, and `contract_drift` on a moved projection and on a missing file | AC-1, AC-5, AC-6, AC-7 |

**Test decision:** the gate's failure path is proven twice — once in the suite
(`contract_drift` over a projection whose endpoints moved) and once by
mutation, which is what `.claude/rules/backend/testing.md` asks for. The
mutation run changed one **field description** in
`views/holdings_allocation.py` — text the inventory tables do not even print —
ran `make catalog-check`, saw it go red on the digest alone, and restored the
file:

```
-| [`holdings.allocation.v1`](#holdingsallocationv1) | `63d89e469006` | 16 | …
+| [`holdings.allocation.v1`](#holdingsallocationv1) | `ec72f84f55f2` | 16 | …

docs/catalog/CONTRACT.md is stale — a projection changed. Regenerate it:
  cd backend && make catalog
```

A hand-edit of `docs/catalog/CONTRACT.md` was rejected the same way. Both were
restored; `git status` over `src/app/presentation/views/` is clean.

## 8. Open decisions

| # | Question | Owner | Resolution |
|---|---|---|---|
| OD-1 | The ticket asks for the six schemas to be **transcribed by hand** from GGU-16..22 into a Figma page, and treats the transcription as the deliverable. | TL — **re-baseline: generate it** | GGU-16..22 do not exist in this repository, and under ADR-K D-14 the component schema contract already *is* the projection registry. A hand-copied inventory would be a second declaration of a fact the code already states — and a second declaration drifts the moment a field changes, which is the precise failure GGU-41 exists to prevent (the same lesson `.claude/rules/backend/testing.md` records: "a documented property needs a test that bites"). The ticket's *intent* — a frozen, versioned, designer-facing field inventory — ships in full; its *method* is inverted. What the ticket calls the Figma "Schema Contract" page becomes a page that cites `docs/catalog/CONTRACT.md` by projection id and digest instead of restating it. |
| OD-2 | The ticket names **six** components. Only two are registered today; four land in parallel tickets. | TL — **never count, never name** | The generator is driven entirely by `REGISTRY.all()`. There is no list of six, no expected count, no import of a view module and no test asserting how many projections exist — the extensibility guarantee of ADR-K D-15 applied to this document. The four incoming projections appear the moment they register, and the gate then requires the contract to be regenerated in their own PR. |
| OD-3 | `order.ticket.v1` will be the only interactive component, and it does not exist yet. How is "this field is an input, with these bounds" expressed before it does? | TL — **an input is a payload field named after a declared option** | ADR-K D-3 already fixes what a caller may send: a declared, bounded option and nothing else. So interactivity is not a new annotation to invent — it is the round trip that already exists. A payload field whose name matches an option of the same projection is editable, and the Input column prints that option's bounds, which are the validation the design must respect. This is testable today (a stand-in payload in `test_inventory.py` proves it) and costs `order.ticket.v1` nothing but a naming convention. The alternative — a per-field flag on the DTO — would let a projection declare an input that the registry cannot validate, which is the exact thing D-3 forbids. **What `order.ticket.v1` must do:** name each editable payload field exactly as the option that sets it (`quantity`, `limit_price`), and declare that option bounded on its options model. **Resolved by GGU-78 — it did not, and nothing compared the two.** Spec 0018 chose `size`/`size_in` for the sizing pair (ADR-E D-5), so the ticket offered four controls and named two: `symbol` and `side` matched **by coincidence**, `size`'s payload field was called `quantity`, and `size_in` had no payload field at all. The document therefore reported the component as accepting half of what it accepts. The fix keeps this convention and makes the ticket obey it — the payload now carries `size` and `size_in` under their own names — and adds the check that was missing: `tests/unit/presentation/test_declared_interactivity.py` walks the registry and fails when a projection's `inputs[]` and its name-matched fields disagree. Two clarifications this episode earned, both now in the convention: the field names above were illustrative, not a contract (the real options are `size`/`size_in`); and **a derived figure is never an input** — `quantity` stays `quantity` because under `size_in="usd"` it is the size *divided by the entry price*, so naming it `size` would advertise as editable a value the options model does not accept back. |
| OD-4 | Is "pre-formatted" decided by the `*Display` name? | TL — **no: by the pair, and only when the object is nothing but the pair** | Keying on a name would make the contract lie the first time a projection names its string something else, and would classify a bare `Annotation.text` — prose that already contains its numbers — as raw data. The rule reads structure instead: a string inside an object holding **exactly** one figure and this string is the printable half of an ADR-E D-2 pair; every other string is `text`; a figure is `raw`. The `len == 2` clause is load-bearing and was added after the rehearsal in OD-9 found the looser version calling `order.ticket.v1`'s `title` pre-formatted, purely because an editable integer sat beside it. `test_schema_roles.py` passes the *same* string fragment through both paths so the rule cannot quietly become a name check, and pins the ticket shape that exposed the bug. The document states the rule, and states that `display` is the convention it describes rather than the thing it reads. |
| OD-5 | The ticket asks design to freeze **loading** and **error** states alongside default and empty. | TL — **three of the four; say why the fourth is not here** | `default`, `empty` and `variant` are facts about the schema and are in the tables. `loading` and `error` are not: no projection carries an `isLoading` flag, because a surface is either streamed or not yet streamed (ADR-K D-19), and a failure arrives as an RFC 9457 problem document rather than as a payload with an error field. Inventing an `isLoading` column to satisfy the ticket would put a capability in the contract that the backend does not have — the honesty rule the diagrams and the compliance corpus follow. The preamble names both states and points design at the transport instead. |
| OD-6 | Where does the version identifier live — a `v1` tag, or a hash? | TL — **both, and they answer different questions** | The versioned id (`holdings.allocation.v1`) is the **name** a client binds to and a designer cites; it is immutable by D-9. The digest is the **proof** that the thing behind the name has not moved. A tag alone cannot detect drift, which is what the ticket actually asks for; a hash alone is not something a human can cite in a Figma cover. AC-6 shows why the digest has to cover the whole payload schema and not just the printed tables: a changed field *description* moves the digest and nothing else. |
| OD-7 | Adding a fifth consumer to ADR-K D-14, which names four. | TL — **a fifth consumer, no ADR change** | D-14's ruling is that registering once publishes everywhere and that no consumer is hand-maintained; it enumerates the four that existed when it was written. This document is a fifth instance of the same rule, not an exception to it, and it is added the way D-15 requires: a pure renderer over `REGISTRY.all()`, with no shared file edited to add a chart. If a sixth appears, D-14's list is worth rewording; one does not warrant amending an accepted ADR. |
| OD-9 | Does a generator with no list of components actually pick up an unseen projection — and does the inventory survive one? | TL — **rehearsed with a throwaway module, and it found a bug** | A stand-in `order.ticket.v1` (a payload echoing a `top_n` option, plus a `Total`) was dropped into `views/`, `make catalog` run, and the module deleted. Three results. The section appeared with **nothing edited** — the D-15 guarantee, end to end. The Input column lit up correctly: `top_n` read `input · integer 1..20` and the header read ``**Editable fields:** `top_n` ``, so OD-3's convention works before the real projection exists. And it exposed the false positive OD-4 now records — worth more than the two confirmations, and the reason the rehearsal was run at all rather than reasoned about. |
| OD-8 | The preamble is prose inside a Python string, and Markdown table rows cannot be wrapped under the 88-character limit. | TL — **bullet lists, not tables, in the preamble** | Three options were on the table: raise the line limit (a team threshold, never lowered *or* raised in a feature PR), read a `.md` template from disk (I/O in the presentation layer, which ADR-K D-6 forbids), or write the legend as wrapped bullet lists. The third costs nothing — the legend reads at least as well as a table on GitHub and on a phone — and keeps the layer pure. The generated tables are unaffected: `CONTRACT.md` is Markdown, and ruff does not lint it. |
