# 0052 — The comparison gets a turn

**Status:** In progress · **Ticket:** GGU-143 · **Area:** `backend/`
Closes the `scenario.comparison.v1` entry in
`tests/unit/agent/catalog_reach_data.py::DECLARED_GAPS`, which said *"the next
agent feature should take it"*. Implements the surface
[`backend/0017`](0017-scenario-comparison.md) declared and
[`backend/0051`](0051-the-comparison-ranks-what-it-can-defend.md) taught to
rank.

## 1. Problem

`scenario.comparison.v1` is registered, served by the read endpoint, bound by
a Flutter component, covered to 100 %, published in both catalog artefacts and
— since GGU-141 — measured against the design. **No turn draws it.**

Found by driving the running client rather than by a failing test: asking the
assistant to compare lot methods answers with the tax-lot table or the
allocation surface, because no tool emits a render intent for the view. The
only place a person meets the card is the catalog gallery's thumbnail, which
crops it above the metric rows.

Four tickets of work produced a component the product cannot show. That is
GGU-79's lesson one layer further out — *"adding a component edits no existing
file" is a claim about the whole path to the screen, not about the registry* —
and the repository had already written it down: the gap was **declared**, in a
test, with an owner's note attached, and it stayed declared while three specs
shipped around it.

## 2. What ships

**`compare_lot_methods`** (`app/agent/tools/compare_methods.py`) — costs one
sale under two or three lot-selection methods and emits
`RenderIntent(view="scenario.comparison.v1", …)`. Registered by its own last
line; no shared file was edited to discover it.

**A fifth curated chip**, `lot-methods` → *"Which lot method?"*, and the
scripted turn behind it, so the flow works with **no model provider
configured** — which is how the demo runs.

**The position and the size moved to `agent/tools/sale_size.py`.** Two tools
now name a sale the same way, and `units()` carries reasoning (the quantize,
and why it is not the rounding ADR-E D-3 forbids) that must not exist twice.
`simulate_sale`'s arguments are that base plus `lot_method`; the comparison's
are that base plus `methods`, which is the whole structural difference.

## 3. Decisions

**D-1 — the tool does not name a tax rate.** The card prints the rate it
costed with, because this demo knows no taxpayer and a rate nobody chose would
be a tax claim nobody could check (GGU-134). A rate the *model* chose would
make that printed assumption model-authored, which is the same defect one
layer up. `extra="forbid"` is what enforces it, and the test asserts the
effect rather than the absence of a field.

**D-2 — the tool does not rank.** `presentation/scenario_verdict` decides
which column wins each row and the card writes its own summary sentence. A
second ranking in `app.agent` would be two declarations of one fact — and
`app.agent` may not import `app.presentation` in any case, which is the
layering rule doing its job rather than an inconvenience.

**D-3 — the sentence defers the verdict to the card.** The answer names the
sale and the methods; it does not say which won. Not squeamishness: the
winner is a *rendered* claim with a tint and a tick behind it, and a sentence
that repeated it would be a second copy free to disagree after an option
changed.

**D-4 — an over-sell answers, and draws nothing.** The same shape
`simulate_sale` uses (spec 0013 OD-3): the shortfall is the useful part, so it
is in the payload rather than in a raised exception the loop flattens to
`tool-failed`. And **no render intent** — a comparison fails every column
identically, so three empty columns would be pretending to be a decision
(spec 0017 OD-5).

**D-5 — `methods_display` has no branch for a single method.** `min_length=2`
makes a one-column comparison inexpressible, so a guard would be a branch no
caller can reach and the coverage contract would then ask for a test that
cannot be written. The structural refusal is the same one spec 0017 OD-3 makes
for two symbols.

## 4. One check was changed, and it is not a loosening

`test_tool_argument_bounds.py::_is_bounded` returned `False` for
`type: boolean`, so `include_wait` — the first boolean argument any tool has
published — failed it. `boolean` now joins `null` as trivially bounded.

The distinction matters because §5 of `ci-conventions.md` is mostly a record
of checks that were quietly weakened. This one is not: the check's **subject**
is *can the model make this argument arbitrarily large*, and `type: boolean`
admits exactly two values. A bool reaching `return False` was the helper
having no case for a shape no tool had used yet, not a bound it was enforcing.
Nothing that used to fail now passes.

## 5. Acceptance criteria

- **AC-1** The tool emits a render intent whose view the **real registry**
  resolves and whose options the **projection's own model** validates.
- **AC-2** One column per requested method, in the order requested; the
  columns share the sale and differ on what it realises.
- **AC-3** The sentence's subject block and the rendered card name the same
  symbol, size and price.
- **AC-4** A repeated method and a single method are both refused, as the
  option model's own errors.
- **AC-5** An over-sell answers with `position-too-small` and no render
  intent.
- **AC-6** The model cannot send a tax rate.
- **AC-7** `scenario.comparison.v1` leaves `DECLARED_GAPS` and joins the
  reachable set, in this commit.
- **AC-8** The chip runs with no model provider configured.
- **AC-9** Both gates green.

## 6. Test plan

`tests/unit/agent/tools/test_compare_lot_methods.py` (the payload and the
refusals) and `test_compare_render.py` (the intent, resolved through the real
registry and rendered). Neither compares the intent to a literal it wrote
itself, for the reason `test_simulate_sale_render.py` records: the tool spells
the view id as a plain string, which makes the id and its options two
declarations of one fact.

**Mutation check, as `.claude/rules/backend/testing.md` requires of wiring.**
Commenting out the module's `register(...)` line turns **three** tests red,
including the end-to-end scripted turn:

```
FAILED test_registry.py::test_load_tools_discovers_every_tool…[compare_lot_methods]
FAILED test_registry.py::test_every_module_that_registers_a_tool_is_named_in_the_expected_list
FAILED test_scripted_turns.py::…[compare what each lot-selection method would cost on the same sale]
3 failed, 233 passed          # restored: 241 passed
```

**The new suites import `app.presentation.views` through their fixture**, so
they populate the registry themselves. Without it `test_compare_render` would
pass only when some other module happened to import the views first — which is
what `test_simulate_sale_render.py` relies on today, and why running that file
alone fails four of its five tests. Recorded rather than fixed there; it is a
latent order dependence, not a false claim.
