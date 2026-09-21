# Harness log

One entry per iteration (PR). Newest first. Record what changed in the code
**and** in the harness (CLAUDE.md, rules, hooks, commands, agents, ship gate,
specs, docs), plus what the next person needs to know. This file is the
repository-side memory; the agent's private memory mirrors the decisions.

---

## 2026-09-21 — GGU-59 the scenario comparison card · spec `specs/frontend/0004-scenario-comparison.md`

**Branch:** `feat/GGU-59_scenario_comparison`, cut from `develop` at `c6dd5b2`.
Serves GGU-18 and design GGU-42.

**What changed.** The third catalog component: `scenario.comparison.v1`, the
same sale costed under FIFO / LIFO / HIFO side by side. Twelve files under
`app/lib/components/scenario_comparison/`, nine test files, two goldens, and
the regenerated manifest. **No hand-written file was edited** — the seam held
end to end for the first component added since GGU-79 closed it, so this is
also the first independent confirmation that it works.

**The design asked for a winner and the card does not name one.** Its schema
declares `scenarios[].recommended` and `metrics[].betterWhen`; its artboards
badge one column `★ Recommended` and tint the better cell of each row green
with a tick. Spec `backend/0017` OD-4 rules both out and the backend emits
neither, so rendering them would be the client inventing a claim. The reason
is not process: marking one disposal strategy "recommended" is tax advice, and
whether FIFO's `+$3,825.00` (all long-term) beats LIFO's `+$1,305.00` (all
short-term) depends on a marginal rate and a jurisdiction nothing here knows.
The card renders `spread` — the arithmetic difference and which method sits at
each end, which is data the columns already show — with the backend's own
`Not advice` note verbatim beneath it. `specs/frontend/0004` OD-3 carries the
full argument so nobody has to rediscover it.

**A finding worth keeping: Flutter's border is not CSS's border.** The design
is `box-sizing: border-box`, so its 1 px hairline sits *inside* the declared
width. `DecoratedBox` and `CustomPaint` paint over the child and reserve no
space, so the same padding left the content box 2 px too wide and every grid
track wrong — 209.30 / 155.03 against the designer's 208.48 / 154.44. Every
bordered element now pads by `ScenarioComparisonLayout.hairline` as well. The
geometry test found it; **no golden of this card could have**, which is the
next point.

**The golden is narrow because the card is all text.** ADR-L D-15's measured
noise floor is 0.69 % and it lives in glyph edges; a card with no bars and no
connectors is nothing but glyph edges, and the defect most worth catching here
— a token one step off, `#F0EDF5` against `#F0EEF5` — moves well under 1 %. So
the colours are asserted **directly**, against the rendered `BoxDecoration`,
which catches a one-step error exactly; the goldens capture only the column
header's painted hairline, with no text in frame. First cut used the design's
track width and a radius mutation moved 1.66 % against a 1.5 % tolerance — a
margin of 1.1×, not a gate worth trusting. Cropping the frame to 56×30 raised
it to **5.00 %**, 3.3× the tolerance. **The tolerance was not touched**; it
goes down as noise is understood, never up to absorb a failure.

**Harness.** No rule, hook, command or diagram changed. Diagram 12 is
layer-level and a third component adds no layer, package or import rule —
which is the seam claim restated as a diff.

### What the next person should know

- **`frontend/CLAUDE.md`'s "only file naming a `Color`" sentence is false, and
  GGU-57 is fixing it — independently.** It and `chart_tokens.dart` both say
  `chart_tokens.dart` is *the only file in `app/lib/` naming a `Color`*;
  `scenario_comparison_tokens.dart` names eight. The alternative was adding
  four fields to `ChartPalette` **and** `ChartTokens` — two shared
  hand-written files edited in order to add a component, which ADR-L D-3
  exists to prevent — and three of the four are not chart roles anyway (a
  table's row rule, a header hairline, a caption). No test enforced the claim,
  so nothing went red.

  **Two components hit this from two directions in the same week and reached
  the same answer without coordinating**: GGU-57's tax-lot table has its own
  token file for the same reason, and its PR (#71) replaces the count with a
  rule in `frontend/CLAUDE.md`. Whichever merges first fixes it; the second
  conflicts on that line and should take the rule form. `specs/frontend/0004`
  OD-8 keeps the reasoning and asks for the rule to get a **test**, since
  replacing one unenforced sentence with another only resets the clock.
- **`ViewPayload` has no boolean accessor**, so `spread.differs` is unreadable.
  The card reads the two ends instead — and **the review caught that the first
  cut of that rule was wrong.** It required *both* ends, while the contract
  makes `spread.highest` and `spread.lowest` `default null` **independently**
  and ties neither to `differs`: a payload naming one end would have had the
  card drop a name the backend sent *and* claim the methods coincide. The rule
  is now `||`, lives once on the model as `namesAnyEnd`, and the `||` → `&&`
  mutation turns two tests red — it turned none before. If a second component
  wants a boolean, add `ViewPayload.flag(path)` in a PR of its own; that is a
  **deferral, not a prohibition** — ADR-L D-3's subject is dispatch, and
  `geometry` set the precedent that widening `ViewPayload` is an amendment
  (OD-2, reworded after review).
- **Four contract fields are bound by nothing**: `short_term_lots`,
  `long_term_lots` and `lots` per column. The counts are raw integers with no
  `*Display` companion, so printing one is the client turning a number into
  text; `lots` is internal ids. OD-6, not an oversight.
- **Two more things the design asks for have no field**: row labels (its
  `metrics[].label` — ours are client copy, OD-1) and a colour for a gain or a
  loss (`scenario.comparison.v1` carries no `direction` enum the way the
  waterfall's buckets do, and reading the sign out of `"+$3,825.00"` is exactly
  what the rule forbids — OD-7).
- **Measure the rendered DOM, still.** Eight colours and eleven geometry values
  were read with `getComputedStyle` off the served page. The metric-name colour
  cross-confirms against the catalog index's own token legend.
- **A `.dc.html` design page opened from `file://` renders its chrome but does
  not boot its data binding** — the table shows `{{ h.label }}` / `{{ r.label }}`
  where the figures belong. Over `http://` the same file boots fully (547
  nodes, no placeholders). Both were observed on this page, minutes apart, so
  it is the scheme and not the wait. **Check for `{{` before measuring
  anything off one of these pages**; a pixel claim taken off a placeholder is
  worse than no claim. Other pages in the set reportedly do boot under
  `file://`, so test the page in front of you rather than assuming either way.
- **The newer fourteen-screen design export changes nothing here — except one
  thing.** Re-measured `.design-refs/Catalog_ScenarioComparison.dc.html` in
  both artboards: every colour, padding, radius, width and both grid rules are
  identical to the earlier export. The miss it caught is that the `Metric`
  caption is weight **500 with normal tracking**, not the eyebrow's 600 at
  `0.08em` — this card had been reusing `caption` for it. Now its own slot,
  asserted against `caption`'s weight so they cannot silently converge.
- **The design index still says `ComparisonCard`.** Its detail page and the
  backend both say `ScenarioComparison`; the schema block is authoritative and
  `catalog_contract_test.dart` is what would catch getting it wrong.
- **Spec numbering has no gate, and it has now collided twice.** This spec was
  written as `0003` and renamed to **`0004`** because GGU-57 (#71) was landing
  `0003-taxlot-table.md` with an `assets/0003-taxlot-table/` directory beside
  it — renaming this one was the cheaper move. That is the *second* instance:
  `develop` already carries two files numbered `0002`
  (`0002-a2ui-agent-path.md` and `0002-chart-primitives-and-waterfall.md`).
  `.claude/rules/backend/sdd.md` says `NNNN` is "the next free number", but
  nothing computes it and nothing checks it, so two branches cut in the same
  week reliably pick the same one. Left as-is here — the `0002` pair is
  pre-existing and not this ticket's to move — but it wants either a gate
  (a check that no two specs in a directory share a prefix, the same
  anti-collision shape `manifest-check` already has) or a convention that does
  not depend on branch timing.

---

## 2026-09-20 — GGU-53 the catalog contract as JSON · spec `specs/backend/0021-machine-readable-catalog.md`

**Branch:** `feat/GGU-53_catalog_json`. Server half of GGU-53 only; the Flutter
harness and `catalog_contract_test.dart` stay with the client half (blocked by
GGU-1).

**What changed.** `docs/catalog/CONTRACT.md` proved the contract to a human and
to nobody else — a Dart test cannot parse a table, so the one fact the client
binds to (the A2UI component name) was published nowhere a machine could read.
`docs/catalog/view-catalog.snapshot.json` now ships beside it: per view the
component type, the view id, the digest, the field paths, the options schema
and the rendered example. `presentation/catalog_artifacts.py` holds both
renderings as a list, `render_all(REGISTRY.all())` produces them in **one**
pass, and the existing generator script writes and `--check`s each. No new gate
step, no new Makefile target, no change to `ship-gate.json` — the command it
already names covers both files, which is what §5 of the CI rule asks for.

**The mutation check found the point of the ticket.** Renaming one adapter's
component (`DonutChart` → `PieChart`, nothing else touched) turns the new suite
red three ways and `catalog-check` red on the snapshot — while
**`CONTRACT.md` stays current**. The Markdown prints payload fields, not the
adapter's output, so the string the Flutter `FinanceCatalog` registers against
was the one string no gate watched. That is the drift GGU-53 describes
(`WaterfallChart` vs `attribution_waterfall`), reproduced on demand.

**For the next person:**

- **A generated artefact is an entry in a list now, not a script.** Adding a
  third rendering of the registry means one `Artifact(path, render)` in
  `ARTIFACTS` and its renderer. If you find yourself writing a second
  `--check` script or a second gate step, stop.
- **The component name is read, never written.** `component_of` validates the
  shipped example back into the DTO and asks the projection's own adapter, so
  the snapshot cannot carry a name the backend does not emit — and the round
  trip proves the example still deserialises, which is the client test's
  property asserted server-side.
- **One named case, never the list.** The suite asserts the *rule* over
  `REGISTRY.all()` plus a single pinned example (`holdings.allocation.v1 →
  DonutChart`). Listing all six components would rebuild the hardcoded
  inventory 0019 OD-2 deleted and would fail the day a seventh registers.
- **A double gate has to be symmetric.** The JSON was checked from inside the
  suite and the Markdown only by the generator script, which coverage does not
  measure (`source = ["app"]`). `test_contract_matches_the_registry` closes it:
  both artefacts are now compared against the registry by a test, so a
  generator that stopped reporting one cannot let a stale file through. Found
  by the `backend-reviewer` agent, which is what it is for.
- **Prose hits the line budget too.** The cross-reference paragraph pushed
  `catalog_preamble.py` to 162 lines; the legend moved to
  `catalog_legend.py` at the seam between "what is frozen" and "how to read a
  row". Budgets are not raised for prose.

---

## 2026-09-20 — GGU-82 the client harness · spec client/0001

**Branch:** `docs/GGU-82_client_harness`, PR #46. Documentation and rules only;
no executable code changed.

**What changed in the harness.** The client got what the backend already had:
`client_flutter/CLAUDE.md`, four project rules in `.claude/rules/client/`
(architecture · presentation · testing · security), `specs/client/0001-client-foundation.md`
and `docs/diagrams/11-client-architecture.md`. The four rules are registered in
the root `CLAUDE.md` table; the diagram is registered in both
`docs/diagrams/README.md` and the "when a diagram must change" table in
`.claude/rules/diagrams.md`.

**Why a separate rule layer rather than editing `.claude/rules/flutter/`.**
Those seven files are synced from `somnio-ai-tools` and are overwritten by the
Somnio CLI. They are also written against a different repository — a `mobile/`
root, a `packages/app_ui` design system, an ARB i18n setup — none of which
exist here. `client/architecture.md` opens with a table of the four places the
generic rules name something this repo does not have, and states that the
project layer wins.

**The Dart budget is 220 lines, and the number was measured.** Copying the
backend's 150 across would have been the easy answer and the wrong one: this
workspace's analyzer config puts one widget argument per line, and every file
carries a 14-line Apache header. Of the twelve `.dart` files under `app/lib`,
the median is 65 and the second-largest 128; exactly one exceeds 220 —
`features/landing/view/landing_page.dart` at 247 — and it hosts the genui
surface, owns the connector lifecycle and renders the error banner. 220 is the
line where "does one thing" fits and "does three" does not.

**Things that are true and unflattering, written down rather than smoothed
over.** The client's gate is young, so the temptation was to describe it as
though it were the backend's. Instead:

- `flutter test --coverage` runs and uploads `lcov.info`; **no coverage threshold is asserted anywhere.** The ≥80 %/file bar is a review rule until someone adds the assertion (spec OD-2).
- **Nothing enforces ADR-K on the client.** The rule says so and names the two things that partly carry it: the per-ban greps, and a verbatim-binding widget test that asserts `find.text(fake.marketValueDisplay)` rather than a literal — the literal form passes whether the widget bound or formatted. OD-3 proposes the grep gate.
- `app/pubspec.yaml` declares only `flutter_test`. **`bloc_test`, `mocktail` and `checks` are not dependencies**, though all three generic rules assume them.
- **There is no deep-link surface at all** (ADR-I keeps `Navigator`), so the security rule records the absence as the control rather than inventing a validation policy for a path that does not exist.

Each rule carries a table separating what a command enforces (with the
`ship-gate.json` id and the command string) from what is *review only*. The
standard the ticket set was: do not write a rule that nothing enforces and
state it as though something does.

**Deferred to GGU-1 on purpose.** Timur's PRs #26 (scaffold) and #30 (gate) own
`.claude/ship-gate.json`, `.github/workflows/client-ci.yaml`,
`.pre-commit-config.yaml`, `client_flutter/tool/check_*.sh`,
`client_flutter/README.md` and everything under `client_flutter/app/{lib,test,android,ios}`
plus `app/pubspec.yaml`. Nothing here touches any of them; rules that depend on
one of those checks cite it by id with "lands with GGU-1", the way
`ship-gate.json` already says "Flutter gate lands with GGU-1".

**What the next person needs to know.**

- **`/harness-init` will delete the four new rule rows.** They sit inside the block that command regenerates. Teach it about `.claude/rules/client/` or the rows vanish silently and the rules stop loading. This is the single most likely way this PR quietly undoes itself.
- **Check what `origin/develop` actually resolves to before branching.** This branch was first cut from a stale `origin/develop` (`bf2d0c2`) while the real tip was `c1f758d`, because `.git/config` could not be locked in the worktree and the fetch never updated the remote-tracking ref. The first PR push showed **407 changed files** and would have reverted other people's merged work, including the GGU-1 files this ticket exists to stay away from. `git diff --name-only <base> HEAD` before opening a PR — the file count is the tell.
- The backend gate is green on every step a docs change can break (`catalog-check` and `codespell` included; codespell scans `docs/`, so it covers the new diagram). The 52 integration errors are the Docker daemon being unavailable locally, not this branch.

---

## 2026-09-20 — GGU-83 one instance, because the limiter only works at one

**Branch:** `fix/GGU-83_single_instance`. **Spec:** `specs/backend/0001-backend-foundation.md` (OD-2
resolved) · **ADR:** ADR-F **D-9** settled.

**The defect.** The fixed-window rate limiter and the feature-flag TTL cache both hold state in
process memory. ADR-F **D-4** had required `max-instances = 1`, which bounded them. Dev ran `1/2`,
so the per-principal limit was **twice** what `backend/docs/SECURITY.md` documents — a SOC 2 CC6.6
control describing behaviour the service did not have.

**Why it survived.** D-4 carried *two* properties in one sentence: `as_of` consistency and the
boundedness of these caches. Spec `0020` removed the first reason and retired D-4 with it; the
second went unexamined. Spec `0001` OD-2 had already named the fix, conditional on
"`max-instances > 1`" — and that condition came true when dev was scaled for the cold-start budget,
on cost grounds, against a constraint living in a different document. **Nobody evaluates a condition
written in prose.**

**The decision (TL, Option B).** Pin `max_instances = 1` rather than build a distributed limiter a
week before the demo. `min_instances = 1` is untouched — it is what keeps the instance warm, and
scaling out was never what bought that. Memorystore (Option A) stays the real fix.

**What is actually the deliverable.** Not the Terraform line. The line makes the configuration match
the limiter's capability today; it does nothing the moment someone raises the value.
`infra/scripts/tests/test_rate_limit_ceiling.sh` is what survives the decision being reversed: it
reads the ceiling out of `infra/main.tf` and every `*.tfvars`, the limit out of `core/config.py` and
`env.example`, and both numbers out of `SECURITY.md`, and fails naming every declaration that
disagrees. Registered verbatim as `infra.rate-limit-ceiling` in `.claude/ship-gate.json`, in
`infra-ci.yaml` and in pre-commit (ci-conventions §5 — copied, never paraphrased).

Mutation-checked both ways before it was trusted: Terraform ceiling → 2 goes red naming both
declarations and printing `120 x 2 = 240`; the documented limit → 200 goes red against
`config.py`'s default. A gate that has never been seen red is not evidence.

**The harness change.** `infra-ci.yaml` now also triggers on `backend/docs/SECURITY.md`,
`backend/src/app/core/config.py`, `backend/env.example` and `docs/diagrams/08-infrastructure.md` —
the same reasoning that put `docs/catalog/**` on `backend-ci`: **the edit that breaks a pair must
start the run that rejects it.**

**Next person should know**

- **A cross-declaration test is only worth writing if an unreadable declaration is a FAILURE.**
  Every value is parsed and an unparsable one fails loudly with what was looked for. A check that
  quietly matches nothing is worse than no check — the guard idiom from `test_rules_index.sh`.
- **Resolving an open decision means naming what re-opens it.** OD-2 now lists three conditions, the
  first of which (`max_instances > 1`) is the one the gate enforces. "Resolved" without a re-opening
  condition is how OD-2 stayed conditional and unevaluated for weeks in the first place.
- **The instance count was declared in nine places.** Terraform (`main.tf` + three `*.tfvars`), two
  specs, the infrastructure diagram, the risk register, a domain docstring and a migration
  docstring. Eight are now consistent; `20260920_0005_portfolios.py` still says `max_instances = 2`
  in its module docstring and was left alone because merged migrations are not edited.
  `infra/network.tf`'s `min_instances = 2` is the **VPC connector**, not Cloud Run — do not "fix" it.
- **This is the eighth defect this iteration with the same shape: a property written down and
  enforced by nothing.** The previous seven were caught by reading. This one was caught by an
  *amendment* forcing a re-read of the decision it superseded — which is the argument for amending
  over silently superseding.

---

## 2026-09-20 — GGU-81: the tool schemas Gemini actually accepts · spec `specs/backend/0006-agent-host.md`

**Branch:** `fix/GGU-81_gemini_tool_schema`.

**The product's core flow had never worked, and 1180 tests said it had.**
Every agent turn against the real `GeminiModelClient` came back
`{"kind":"error","code":"dependency-unavailable"}` with `outcome:
model-unavailable`, which reads like a provider outage and is not one. The
request was a 400: `parameters` in a `functionDeclaration` is an **OpenAPI 3
`Schema` proto**, decoded with proto3 JSON rules, and proto3 rejects an
unknown field instead of ignoring it. `payload.py` was passing pydantic's JSON
Schema through unchanged, so `additionalProperties` and `examples` — both of
which our own rules *require* tools to carry — made every turn fail.

**The two consumers of one schema want different dialects.** `api-design.md`
says every field is documented and exemplified; OpenAPI wants that, Gemini
refuses it. The fix is a translation at the adapter boundary
(`infra/model/tool_schema.py`), never a weakening of the tools: the
declarations, the OpenAPI document and
`tests/unit/agent/test_tool_argument_bounds.py` all still see the full schema.

**The subset was measured, not remembered.** One POST per keyword against
`gemini-3.8-flash`, at the `parameters` root and inside a property, keeping
whatever answered 200. 21 keywords are refused, including four that carry a
bound — `const`, `exclusiveMinimum`, `exclusiveMaximum`, `multipleOf` — and
`$ref`/`$defs`, which carry *everything*. `$ref` is therefore **resolved**, and
`const` rewritten as a single-valued `enum`; dropping either would delete a
bound from what the model reads, which is the failure the bounds gate exists
to prevent. The lists live in `tool_schema_keys.py` with the note that they
came from the API.

**What the suite learned.** `tests/unit/infra/model/test_outgoing_tool_schema.py`
builds the real outgoing body from the **real registry** and asserts no refused
keyword survives, plus that no argument lost a bound on the way out. No
network. Mutation-checked: putting `examples` back in the allow-list turns it
red for three of the four tools.

**Next person should know**

- **A fake that is never compared to the real thing is a shared belief, not a
  test.** `payload.py` had 100 % branch coverage against stubs we wrote from
  our own assumption of the format. Spec 0006 OD-7 had even written the risk
  down — *"the Gemini wire mapping has never met the real API"* — and it still
  took a human reproducing the 400 by hand to collect. Coverage cannot see a
  wrong premise; only the provider can.
- **An error taxonomy can hide the defect it reports.** Every provider failure
  leaves as `DependencyUnavailableError("model provider unavailable")`, by
  design (no status, no provider text, ADR-J). That is right for the client
  and blinding for us: a 400 that will never succeed is indistinguishable from
  a 503 that will. Worth a look at whether non-retryable statuses deserve a
  distinguishable log field — the body still must not travel.
- **Gemini 3 answers with `thoughtSignature` on the part beside a
  `functionCall`.** `payload.from_response` ignores unknown fields, so it is
  dropped today. If a future multi-step turn starts failing on the *second*
  model call, look there first.

---

## 2026-09-19 — GGU-41 the frozen component contract · specs 0015–0019

**Branch:** `feat/GGU-41_catalog`, integrating five parallel branches.

**What the ticket asked for, and what it got.** GGU-41 asked for six component
schemas to be **transcribed by hand** into a Figma page from Epic-2 tickets
that do not exist in this repo. Under ADR-K D-14 the schema contract already
*is* the projection registry, so a hand-copied inventory would be a second
source of truth — and the second source is the one that goes stale, which is
the exact failure the ticket exists to prevent. The intent shipped in full;
the method was inverted. `docs/catalog/CONTRACT.md` is generated from
`REGISTRY.all()`, and **"frozen" now means drift is detected**: `make
catalog-check` regenerates, diffs and fails with the command to run. It is in
`make gate`, `ship-gate.json`, the CI Quality job and pre-commit.

It bit during this very integration: the four new projections landed and the
gate went red on a stale contract before any human noticed.

**Four charts, four agents, one convergent finding.** `taxlots.table.v1`,
`scenario.comparison.v1`, `payoff.curve.v1` and `order.ticket.v1` were built
in parallel by agents that could not see each other. Three of them
independently reported the same thing, which is what makes it credible:

> **ADR-K's `Projection` Protocol is bound to `Portfolio`.** D-6 says "domain
> result + options → DTO"; the code says `Portfolio` in three places, and
> `Callable` is contravariant in its arguments, so `render(SomeOtherResult, …)`
> does not even type-check. The four charts fit *only* because their domain
> results are derivable from a `Portfolio` by a pure function.

Recorded in **ADR-K itself** (Consequences → "Known limit"), not in four
specs, so the fifth person does not rediscover it. Deliberately **not** fixed:
no projection needs it yet, and widening the seam speculatively costs every
current view a type parameter it does not use.

**The order ticket, without changing the ADR.** Interactivity cannot live in
`render()` — a projection returns a payload and never receives an event. It
lives in the *declaration*: the editable fields **are** the declared options
(D-3), published as `TicketInput` descriptors; an edit is re-rendering the
same view with one option changed. And the bounds it publishes are proved to
be the bounds enforced — by a test that walks the **registry**, feeding every
published bound back through `validated_options`.

**What I fixed centrally, that no single agent could see**
- **Four test files hard-coded the registered id list**, and three agents
  "fixed" them three different ways (extend, derive-from-registry, loosen to
  containment). Now one written-down list, `tests/catalog.py::SHIPPED_VIEWS`,
  the same shape `EXPECTED_TOOLS` has for tools. Deliberately *not* derived
  from `REGISTRY`: an expectation read from the thing under test cannot fail.
- **`option_bounds` was lying to the model.** Anything it did not recognise
  fell through to the literal `"list of names"`, so a nullable ticker reached
  the model as `symbol (list of names)` and a list of enums as
  `methods (list of names)`. **Two charts changed their own design to route
  around the wording** rather than send a lie — which is how one defect in a
  shared file becomes four private workarounds. It now follows `$ref`s into
  `$defs`, describes each `anyOf` branch, and when it truly does not recognise
  a shape it *says so* instead of guessing. `tests/unit/presentation/
  test_prompt_bounds.py` walks the registry and fails if any option reaches
  the model described as unrecognised.
- Split into `option_text.py` when `prompt.py` went over budget, and the
  `if`-chain became a dispatch table when xenon ranked it C.

**Next person, read this**
- **A guessed description is worse than an absent one**, because the model
  acts on it. That is why the fallback names the gap.
- The four Flow B/C charts all score `fitness = 0` — they are asked for by id
  and never volunteered. A backend that offers a sale card over a plain
  portfolio read is proposing a trade.
- `scenario.comparison.v1` has **no** `recommended` field, and never sorts by
  outcome — sorting by outcome is a ranking with the label filed off. Picking
  a lot method is tax advice and depends on a marginal rate the backend does
  not know.
- After touching a projection: `cd backend && make catalog`, commit the
  contract. Otherwise the gate is red, by design.

---

## 2026-09-19 — Closing the gates · no ticket

**Branch:** `chore/close_the_gates`, straight onto `develop` after the thirteen
PRs landed.

**The hole this closes.** Three times in one iteration a property was written
down, believed, and enforced by nothing — and every time the gate was green.
The worst of them, `symbols` advertising a ten-character bound while accepting
five thousand, was fixed in `get_holdings_summary` by review. **It was still
live in `compute_attribution` after the merge**: `maxItems: 20` on the list,
and items of `{"type": "string"}` with no bound at all.

Fixing it again per tool does not scale — the next tool is written by whoever
is next. So the rule is now enforced over the **registry**:
`tests/unit/agent/test_tool_argument_bounds.py` walks every registered tool
and fails, naming tool and field, on any leaf that can accept unbounded input.
A new tool is covered the day it registers.

Mutation check, run: reverting the `compute_attribution` fix turns it red with
`compute_attribution.symbols is published to the model with no bound on its
size`; restoring it goes green. The guard also tests itself — a bare string, a
capped array of unbounded items, and `^\w+$` must all fail it.

**One subtlety worth keeping.** The first version read the registry live and
passed alone but failed in the full suite: other tests register doubles into
the process-wide registry at runtime, so the gate depended on test order and a
double's loose schema could fail a check about the tools this backend actually
ships. It now snapshots at import, before any test runs.

**Harness** — `.claude/rules/backend/testing.md` gained two sections: *A
documented property needs a test that bites* (with the three instances, and
the rules: two declarations of one fact get a test comparing them; wiring gets
a mutation check; enforce over the registry, not per instance; branch coverage
does not see a conditional expression) and *A payload is wrong when two of its
own numbers disagree*.

**Next person, read this**
- The three gate definitions — `.claude/ship-gate.json`, `backend/Makefile`,
  `.github/workflows/backend-ci.yaml` — were checked after the merges and are
  still identical. They drift silently; check them after any integration.
- The Flutter half of the gate still does not exist. `ship-gate.json` says it
  lands with GGU-1, which is open as PR #26.

---

## 2026-09-19 — Delivery follow-ups · spec `specs/backend/0012-delivery-followups.md`

**Branch:** `feat/backend_followups`, stacked on `feat/GGU-3_a2a_surface`. Six
deep. **No Jira ticket** — every item here was already decided in ADR-K's
*Delivery speed* section and carried as an open decision in specs 0005 and
0010; none of it needed a new one.

**Why it mattered.** ADR-K D-18/D-19/D-20 had shipped as written-down
intentions. Three caveats were sitting in the tree as prose — "not
incremental", "no batch", "no ETag" — which is the state where a decision
quietly stops being true. The demo is judged on time-to-first-widget, and all
three pushed the wrong way.

**Code**
- `agent/events.py` + `services/agent_loop.py` — the model/tool loop is now an
  **async generator**. `AgentService.run_turn_events` yields a `SurfaceReady`
  the moment a tool returns a render intent; `run_turn` stayed as a thin
  collector, so no existing caller moved. The loop moved to its own module
  because a generator that also owns telemetry and history is two jobs.
- `services/a2a_events.py` + `a2a_service.py` — the adapter forwards a
  `render-intent` event per surface, mid-turn. The event shapes moved next
  door: A2A is alpha, and the module that follows it should not also be the
  one that runs turns. **The terminal `message` still carries the full
  `renderIntents` list**, so spec 0010 AC-2 holds and no client breaks.
- `POST /v1/view-renders` (`api/v1/view_renders.py`, `…_openapi.py`,
  `services/view_render_service.py`, `schemas/view_renders.py`) — the
  heterogeneous batch, **per-entry status**. One unknown view is that entry's
  404; the other entries still render. 201 with no `Location`, and the
  operation says why.
- `api/caching.py` — strong `ETag`, `Cache-Control`, `If-None-Match`, 304, as
  a **dependency with its own tests**, applied to both view reads. The next
  read endpoint gets revalidation for one parameter and one call.
- `presentation/endpoints.py` — serving endpoints named once. Adding the batch
  route would otherwise have meant editing every chart module, which is D-15's
  coupling in reverse.
- `core/errors.py` now owns `PROBLEM_TYPE_BASE`; `api/errors.py`,
  `api/openapi.py` and the batch service share it instead of spelling the URI
  three times.
- `presentation/contract.py::catalog_entry` — one description of a catalog
  entry, used by `ViewService.catalog()` **and** by the route's OpenAPI
  example, so the documented catalog is the served catalog.

**Harness**
- **`.claude/rules/backend/api-design.md` §2 required a request and a response
  example on every operation, and nothing enforced it.** `test_openapi_contract.py`
  checked summaries, ids, tags, statuses, parameters and schema properties;
  `test_openapi_projections.py` checked only the projection half. New
  `tests/unit/api/test_openapi_examples.py` closes it, following `$ref`s so
  `json_schema_extra` counts exactly as the rule says it should. It turned
  eight existing operations red — `/healthz`, `/readyz`, both feature-flag
  routes, `/v1/me`, `/v1/me/audit-events`, `/v1/views` and the agent card —
  and **every one was fixed by adding a real example, none by relaxing the
  test**. `POST /` (A2A) is the single exemption, named with its reason in
  `WITHOUT_EXAMPLES`, and a third test fails if that list ever names a route
  that no longer exists.
- Diagrams updated in the same change: `05-agent-turn.md` (the loop yields;
  `SessionService` drawn as planned), `06-response-shaping.md` (three callers,
  the batch as a resource, the ETag box), `03-backend-layers.md` and
  `04-request-lifecycle.md` (`ConditionalResponse` is a dependency, not
  middleware).
- `specs/README.md` indexes 0012; spec 0010's OD-3 now points at where it was
  closed, and its OD-2 at why it was not.

**`backend-reviewer` findings, all closed in the same commit**
- **A model provider raising something untranslated reached no reporter and
  emitted no `agent.turn` metric.** Pre-existing, but this change made the path
  reachable *and* testable, so it is fixed here: `run_turn_events` now reports
  and counts every failure (`outcome="error"`) before re-raising. The A2A
  stream is the only transport that can swallow it — by then the client holds
  a 200 — so the turn is the last place that can still report.
- `Vary: Authorization` added beside `Cache-Control` on both reads: the bodies
  are subject-scoped and `private` alone was the whole argument.
- `max-age=60` replaced with `private, no-cache`. The old comment claimed the
  window was short so a feature flag took effect quickly — but a `max-age`
  means the client does *not* ask, so a switched-off endpoint kept rendering
  client-side for a minute. The comment and the header now agree.
- The catalog's entity tag is computed **once at import**, not per request: it
  dumps every options schema, and doing that on the 304 path is exactly the
  compute revalidation exists to avoid.
- `reviewer@google.com` in the `/v1/me` example replaced with a reserved
  `example.test` address — an e-mail is PII and this one is published in
  `/openapi.json`.
- `ViewDescriptor.endpoints`' field example was stale the moment the batch
  route landed; it now matches what the catalog actually serves.

**Verified locally before the PR**
- `make gate`: 609 tests, **100 % branch coverage**, ruff/basedpyright/budget/
  xenon/vulture/interrogate/deptry/pylint/codespell clean, pip-audit clean.
- No mutation check needed: no new auth, rate-limit or masking logic. The
  batch route reuses `PrincipalDep`, `require_feature` and the existing
  problem handler, and the unauthenticated sweep in `test_openapi_contract.py`
  covers it by construction — a missing `PrincipalDep` turns it red.

**Next person should know**
- **`contextId` is still not resolved, and that is deliberate** (spec 0012
  OD-3). GGU-46's session code merged onto `ggu46-integration`; this stack was
  never rebased onto it, so there is no `SessionService`, no
  `conversation_session` model and no `session_repository` in this tree —
  nothing to resolve a `contextId` *against*. `a2a_service.py` still passes
  `history=[]` and says so. **Whoever rebases this stack onto the session work
  owns that item**, and the rule is unchanged: resolve against the verified
  subject or treat as unknown, never trust the id alone.
- The A2A `render-intent` event kind is **ours, not the protocol's** (spec 0012
  OD-2). A2A has no "surface ready" event and its artifact semantics are
  unsettled, so guessing at `artifact-update` would have invented a contract we
  do not control. It lives in one module; when A2A settles, one file changes.
- ADR-K D-20's other half — memoising the domain build and each render — is
  **not** done (OD-4). A 304 already removes the body from the wire; a render
  cache keyed by *(subject, view, options)* is unbounded memory in a process
  that seeds a portfolio per subject, so it needs an eviction decision, not a
  decorator.
- Docker is needed for the integration suite, and in a sandboxed shell the
  daemon socket is refused — run `make test` with the sandbox off, or point
  `TEST_DATABASE_URL` at a running PostgreSQL.
- Adding a chart still touches only its own module, but it now imports
  `PORTFOLIO_ENDPOINTS` from `presentation/endpoints.py` instead of spelling
  its serving endpoints out.
## 2026-09-19 — GGU-38 payoff tool · spec `specs/backend/0014-payoff-tool.md`

**Branch:** `feat/GGU-38_payoff_tool`, stacked on GGU-39 (holdings). Seven deep.

**What it answers.** "What does $500 of SOL do to me if the price drops 20 %?"
— twenty-six numbers the model must not compute, including the dollars-to-units
division. `payoff` returns them all pre-formatted, plus three named scenarios.

**Code**
- `domain/payoff.py` — `PayoffPoint`, `PayoffCurve`, `bracket()`.
- `domain/payoff_pricing.py` — `payoff_curve` (the grid and the profit at each
  point); `domain/orders.py` — `order_quantity` (the one division). Split from
  the entities under the line budget, along seams that were already there.
- `agent/tools/payoff{,_limits,_order,_rows}.py` — the tool, its bound table,
  its declared arguments and its display shaping. No shared file edited;
  `load_tools()` finds it.
- `domain/errors.py` — `PayoffRangeError` for a grid with no steps.
- `domain/symbols.py` — the `Ticker` type a tool accepts, moved out of
  `holdings_query` now that two tools want the same bound (OD-13).

**The honest half.** The ticket says "risk/payoff curve", which invites an
options reading. This domain is a **spot** book — no strike, no expiry, no
volatility — so the linear part ships and OD-8 names, in order, what would have
to exist in `app.domain` before anything else could: an instrument entity, a
volatility input, a pricing function. No Greeks were faked. The payload carries
a `disclosure` string saying so, in every answer.

**Thirteen open decisions, because the ticket predates this architecture.** The
ones worth knowing: the grid is `steps` **per side** so the entry price is a
sampled point and "P/L at entry is zero" is an equality, not a tolerance (OD-2);
`range_pct` is an **integer percent** and the size a **decimal string**, because
a float ratio cannot be made exact afterwards (OD-3/OD-4); the size is one field
plus a `size_in` unit rather than two optional numeric fields, which removes a
branch that could not be reached or tested (OD-4); an out-of-range request is
**rejected, not clamped**, as the ticket asked — spec 0011 OD-7's precedent
(OD-5); and `sell` is the mirror curve of a spot position, never a short (OD-6).

**No render intent, on purpose (OD-7).** The registry holds a waterfall and an
allocation donut. Neither draws a P/L curve over a price axis, so the tool emits
none rather than aiming a confident wrong chart at a correct answer.
`payoff.curve.v1` belongs to the ticket that owns the component. This is the
first tool that returns figures and no intent by design, so
`docs/diagrams/05-agent-turn.md` now says a render intent is optional.

**What review found — three payloads that could mislead, and a silent test.**
The gate was green for all four; none of them is a kind of defect a gate sees.

1. **A row that contradicted itself.** On the sell path `positionValue` was
   still `quantity × price`, so every row paired `"$7,924.80"` of position
   value with `"-$1,828.80"` of profit — two figures moving in opposite
   directions, in a payload the model copies verbatim. A sale leaves no
   position, so the field is now `null` there (OD-12). The number was not
   wrong arithmetic; it was arithmetic about something that does not exist.
2. **A ladder that printed one price for twenty-six rows.** `{DOGE, range 5 %,
   25 steps}` gave 51 points with **two** distinct displayed prices, a
   break-even indistinguishable from a row losing six dollars, and support for
   both "at $0.13 you make $6.36" and "at $0.13 you lose $6.36". OD-10 had
   pre-approved a *coarse* ladder, not a *degenerate* one. The domain now
   publishes `price_step` and the display asks for the smallest precision that
   keeps two adjacent points apart — `money_display`'s own `precision`
   argument, **not** a second money format, which is what OD-10 was protecting.
3. **An AC with no test.** Commenting out `register(PayoffTool())` left the
   suite green: the tool vanished from the agent, the prompt and the agent
   card, silently. AC-1 now asserts discovery, and the mutation check was
   re-run to watch it go red.

**Verified**
- `make gate`: **637 tests**, 100 % branch coverage, pylint 10.00/10,
  interrogate 100 %, pip-audit clean.
- Mutation check: `register(PayoffTool())` commented out → 1 failed, 613
  passed; restored → green.

**Next person should know**
- A payoff ladder is the one surface where two-decimal money is not merely
  coarse but self-contradictory, which is why it derives its own price
  precision. **Every other surface still shows DOGE at `$0.13`** —
  `get_holdings_summary` included. The durable fix is a per-asset price
  precision on the curated market reference, like `name`, used everywhere at
  once (OD-10, the shape spec 0011 OD-3 gave `logoUrl`).
- `specs/README.md` was missing its 0011 row; added alongside 0014.
- Spec numbers 0012 and 0013 are reserved by the tickets in flight beside this
  one; 0014 was taken to stay out of their way.

---

## 2026-09-19 — GGU-39 holdings tool · spec `specs/backend/0011-holdings-tool.md`

**Branch:** `feat/GGU-39_holdings_tool`, stacked on GGU-3. Six deep.

**Why it mattered.** Spec 0006 shipped `get_holdings_summary` as the reference
tool that proved the registration seam — one fixed ordering, no filter. GGU-39
turns it into the surface the demo actually lands on, which is the entry point
for all three flows. The three questions it could not answer ("just my BTC",
"my biggest losers", "how am I doing overall") each pushed work onto the model
that the numbers-from-tools invariant exists to keep away from it.

**Code**
- `domain/returns.py` — `return_on_cost`, returning `None` on a zero cost
  basis. A return on nothing is undefined, and `0.00%` would call an
  infinitely profitable position flat (OD-2).
- `core/trend.py` — the up/down/flat token, decided from the **rounded**
  figure so it cannot contradict the string beside it. Its own module: it was
  the fifth concept in `display.py` and that file was at the line budget.
- The tool is now four files: `holdings_sort` (the orders, as a table),
  `holdings_query` (bounded arguments, what they select, whether a chart
  fits), `holdings_rows` (how a position reads), `holdings_summary` (the tool).

**What the reviewer caught that the gate could not**
- `symbols` advertised `maxLength: 10` to the model and enforced **nothing**
  per item — a 5 000-character "ticker" validated. The spec's security section
  asserted the bound that did not exist. Fixed with `StringConstraints`, and
  there is now a test comparing the advertised JSON Schema against the
  enforced pydantic schema, because the comment claiming they agreed was
  exactly what the hole hid behind.
- The render-intent suppression closed the `symbols` hole and left the
  identical `sort_by` hole open: "your two worst losers" under a donut of the
  two largest positions. Both are now one predicate in `chart_options`.
- Three tests that could not fail: an ordering oracle that called the same
  production `SORTERS` entry the tool calls (invert the comparison and it
  still passes), a weights assertion that never looked at the payload, and a
  totals assertion that skipped the three figures this ticket added.

**Next person, read this**
- A tool's argument model and the JSON Schema it publishes are **two
  declarations of the same bound**. Assert they agree; a comment is not a
  test. This is now the third time a documented property turned out to be
  unenforced.
- 100 % branch coverage does not see a conditional *expression*. `ZERO if
  ratio is None else ratio` inside a sort key was fully "covered" and never
  once executed with `None`. If a rule is documented, assert it directly.
- `weight` and `value` sort identically by construction and always will;
  `gainers`/`losers` rank by return, not by absolute profit, because absolute
  profit is dominated by position size (OD-4, OD-5).
- `trend` describes the **money**, not the percentage: they round at different
  scales and `up` beside `0.00%` is correct (OD-8).

**Harness** — no rule, hook or command changed. `docs/diagrams/03-backend-layers.md`
gained `core/trend`; `05-agent-turn.md` now draws the render intent as
conditional, which is what OD-1 made it.

---

## 2026-09-19 — holdings price precision · follow-up, no ticket

**Branch:** `fix/holdings_price_precision`, on GGU-37.

**One line of code, and the reason it is worth a PR.** GGU-37's review found
that `simulate_sale` printed DOGE at `$0.13` beside proceeds of `$1,527.60` —
12,000 times $0.13 is $1,560.00, $32.40 apart in the same block. That tool
fixed its own block with a new `core.display.price_display`, and deliberately
did **not** touch `holdings_rows`, which had the identical bug: it was
GGU-39's contract, reviewed one commit earlier, and editing it there would
have collided.

This closes it, with the same helper rather than a second one. Every holdings
row now multiplies back: `$0.1273 × 12,000 = $1,527.60`. Assets quoted in
whole cents are unchanged (`$64,250.00`).

**Next person, read this**
- There are now **two** precision helpers and they answer different questions:
  `core.display.price_display` (how finely is this *asset* quoted) and
  `payoff_rows.price_precision` (how finely must *adjacent grid points* differ
  to stay distinguishable). Neither subsumes the other. Do not merge them;
  do check which one a new surface needs.
- The pattern that produced this bug is the one worth remembering: a figure
  that is correct on its own, rendered beside another figure it no longer
  agrees with. Three separate instances turned up in one day — this one, the
  `positionValue` that rose while the P/L fell (GGU-38 OD-12), and a
  break-even string shared with 25 losing rows (GGU-38 OD-10). **A payload is
  wrong when two of its own numbers contradict each other, even when every
  number is individually right.**

**Harness** — no rule, hook or diagram changed.

---

## 2026-09-19 — GGU-37 simulate_sale · spec `specs/backend/0013-simulate-sale-tool.md`

**Branch:** `feat/GGU-37_simulate_sale_tool`, stacked on GGU-39 (holdings).

**What it is.** The deterministic tool behind Flow B's tax-lot comparator:
*"what if I sold 0.5 BTC?"* — which lots the sale consumes under FIFO, LIFO or
HIFO, the proceeds, the cost basis, the realised result split short-term vs
long-term, and the position left over. The seed has been waiting for it since
GGU-5: BTC's two lots sit at 367 and 363 days, one either side of the 1-year
boundary, precisely so this answer has something to say.

**Code**
- `domain/lot_selection.py` — `LotMethod` and the three orders. Its own module
  because *which lot goes first* is a policy; a fourth method touches nothing
  else. Every order ends in `lot_id`, so a tie cannot reorder between runs.
- `domain/sale_results.py` — `LotConsumption`, `SaleSimulation`. The short/long
  split is **derived** (`pl_in`, `lots_in`), never stored, so it cannot
  disagree with the rows it summarises. `closes()` mirrors the attribution
  waterfall's own closure check.
- `domain/sales.py` — the walk. Read-only: it never calls
  `PortfolioProvider.save`.
- `agent/tools/{simulate_sale,sale_request,sale_rows}.py` — tool, arguments,
  display shaping. Registered from its own module; no shared file edited.
- `agent/tools/ratios.py` — `return_display` lifted out of `holdings_rows`,
  where it was private. Two tools now share one answer to "return on a zero
  cost basis", instead of two copies free to drift.

**Three decisions worth knowing (full set: spec §8, OD-1…OD-9).**
- **Sizes cross as decimal strings**, not JSON numbers. `json.loads("0.5")` is
  a `float` before this code runs, and `domain.money.reject_float` exists to
  refuse exactly that. `quantity`/`amount_usd` are pattern-bounded strings.
- **Over-sell is an answer, not an exception.** The turn loop flattens a
  raising tool to `{"error": "tool-failed"}` — deliberately, since a message
  can quote a holding. So the tool catches `PositionTooSmallError` and returns
  `{"error": "position-too-small", "requestedDisplay", "heldDisplay"}`. The
  model copies "you hold 0.6" instead of inventing it. Invalid *arguments*
  still reject, unchanged (spec 0011 OD-7).
- **No render intent.** Only `attribution.waterfall.v1` and
  `holdings.allocation.v1` are registered, and neither renders a sell
  scenario. A tool pointing at a view that does not exist is the same lie as
  inventing a number. `tax_lots.table.v1` arrives with its component, in
  Epic 2.

**Ticket re-baselining.** GGU-37 was written against the deleted
`backend_python/` sample — `tools.py`, `agent.py`, `tools=[...]` on an ADK
`LlmAgent`, a `py.typed` marker and a pyproject that still needed pydantic.
Every acceptance criterion survives; only the mechanism changed. Recorded as
OD-1 so the ticket's plan is not followed by the next reader.

**Harness** — no rule, hook or command changed. `specs/README.md` gained rows
for **0013 and 0011**: the holdings PR added its spec without indexing it, and
an index that omits a spec is worse than no index.

**Review round (same PR).** The financial walk was hand-checked and held.
Two test gaps did not, and both would have shipped a wrong figure silently.

- **`register(...)` was unproven.** Commenting it out left the whole suite
  green: the tool would have shipped invisible to the model with a clean
  gate. The discovery test is now parametrized over **every** tool name this
  backend ships, plus a companion that counts the modules ending in a
  top-level `register(` call — so a tool added without being listed fails,
  rather than the next person having to remember.
- **The summary payload was never asserted.** Swapping `shortTermPlDisplay`
  with `longTermPlDisplay` stayed green: the tax split inverted, which is the
  entire product value of Flow B, and AC-2's "short plus long equals the
  total" is symmetric under exactly that swap. The published §3 example is
  now a **literal** oracle in `tests/unit/agent/tools/sale_payload.py`,
  asserted whole.
- **`price_display`, new in `core/display.py`.** OD-4 promised a reader can
  multiply the price by the quantity and land on the proceeds. That was false
  for DOGE, ADA and DOT: `$0.13 × 12,000` reads $1,560.00 against proceeds of
  $1,527.60 in the same block. A price now carries `PRICE_PRECISION` (4 dp)
  when cents are not enough, and a test over the curated reference fails if an
  asset is ever quoted finer than that. **`holdings_rows` has the same bug and
  is deliberately untouched** — it is GGU-39's contract, reviewed one commit
  ago; the helper lives in `core` so that fix is a one-line import.
- Both OD-4 tests could not fail (production compared against production);
  they use literal oracles now. Added the cent either side of the whole
  position, the sub-dollar price, and a `position-too-small` clause in the
  tool description so OD-3 is declared to the model rather than hoped for.
  `symbol` is bounded by pattern, not only by length.

**Verified locally before the PR**
- `make gate`: 657 tests, **100 % branch coverage**, ruff/basedpyright/budget/
  xenon/vulture/interrogate/deptry/pylint/codespell clean, pip-audit clean.
- Hand-check of the FIFO half-BTC case against the seed: proceeds $32,125.00,
  cost basis $22,620.00, realised +$9,505.00 = +$8,925.00 long (lot-btc-01,
  367 days) plus +$580.00 short (lot-btc-02, 363 days), leaving 0.1 BTC.
- **Mutation evidence**, each applied then reverted: `register(...)` commented
  out → 2 failures; short/long swapped → 1; `priceDisplay` from the proceeds
  → 3; leftover basis from the consumed basis → 1. All four were green before
  this round.
- No auth, rate limiting or error masking touched, so no security mutation
  check was required.

**Next person should know**
- The seed **cannot** tell LIFO from HIFO on BTC (its newest lot is also its
  dearest), and cannot tell FIFO from HIFO on ETH. `test_sales.py` builds a
  three-lot position whose age order and price order disagree; do not
  "simplify" it back onto the seed.
- Test files obey the 150-line budget too. This feature ships six of them,
  split by responsibility, with the shared pieces in `sale_fixtures.py`,
  `sale_payload.py` and `tests/unit/domain/conftest.py::make_portfolio`.
- `percentage_display` does **not** prefix a `+`. Two spec examples in the
  repo claim otherwise; 0013's were corrected.
- `.claude/commands/feature.md` shows modified in this worktree and is **not**
  in the commit. Writes under `.claude/commands/` are denied to the agent, so
  the on-disk copy could not be updated to the branch's version; it is marked
  `assume-unchanged` so a rebase is possible. Undo that outside the sandbox.

---

## 2026-09-19 — GGU-3 A2A surface · spec `specs/backend/0010-a2a-surface.md`

**Branch:** `feat/GGU-3_a2a_surface`, stacked on GGU-14. Five deep.

**Why it mattered most.** The agent host ran a turn, the presentation layer
shaped payloads, the prompt taught the model both catalogues — and **none of
it was reachable**. Every one of those tickets had merged as code nothing could
invoke. This is the surface that makes them real.

**Code**
- `api/agent_card.py` — `GET /.well-known/agent-card.json`, **public**.
- `api/a2a.py` — `POST /`, JSON-RPC, answering `text/event-stream`.
- `services/a2a_service.py` — the thin adapter (ADR-J D-2). `AgentService`
  still does not know the protocol exists, which is what lets A2A move (it is
  alpha) without the services moving with it.
- `services/agent_card_service.py` — skills generated from the tool registry,
  same principle as the prompt catalogues.
- `api/middleware/install.py` — lifted out of `bootstrap.py`, which the change
  pushed over the budget. Middleware **order is a security contract**, so it
  says so where it now lives.

**Two error shapes, on purpose.** A fault *inside* the protocol is a JSON-RPC
error object at HTTP 200. A fault *before* the envelope is reached — no token,
rate limit — is still an RFC 9457 problem document at its real status. The
manual run shows both. A client parses two shapes and the spec says so rather
than letting it be discovered.

**A second public route.** The agent card is the first addition to the
unauthenticated list since the health probes. `.claude/rules/backend/security.md`
requires a spec note and sign-off, so both exist, and the contract test's
exemption is now a **named `PUBLIC` constant** with the reason attached —
previously a bare set literal inline in one assertion. Adding a public route is
now a visible diff rather than a route that quietly stops declaring a 401.

**Verified**
- `make gate`: **546 tests**, 100 % branch coverage, pylint 10.00/10.
- Live server: the card reads unauthenticated and advertises
  `https://api.finance-a2ui.example` (the **public** URL, ADR-D D-7 — the
  sample advertised `0.0.0.0`) with both tools as skills; a turn streams
  `working` → `message` → `completed`; `POST /` without a token answers a 401
  problem document; `tasks/cancel` answers `-32004` and an unknown method
  `-32601`, both at HTTP 200.

**What review found, and the one that mattered.** The `backend-reviewer` agent
was run over the four unreviewed commits in this stack. It reproduced a
**blocker on the newest attack surface**: a `method` of 64 control characters
is inside the field's 64-character bound, but `repr()` of it is far longer than
the 256-character bound on the error message — so interpolating the caller's
method into the reply raised a `ValidationError` **inside the very helper whose
job is to avoid a transport error**, and the surface answered **HTTP 500**.
That broke AC-3 and contradicted the spec's own claim that these messages are
fixed strings.

Protocol error messages are now **fixed strings, never built from the
request**. The error *code* identifies the fault; echoing the caller's input
back added nothing and cost correctness. Also from that review: `id` and
`params` were the only unbounded fields in the module and `id` is reflected
verbatim, so both are bounded now; the SSE generator caught only `AppError`,
so anything else left the client with a truncated stream whose last state was
`working` and no terminal event; and the controller carried the dispatch
branching the architecture rule forbids, which is now `services/a2a_dispatch.py`.

**The test that will keep paying.** The contract test asserted every non-public
route *documents* a 401 — not that it *enforces* one. A controller that copied
the documented responses and forgot `PrincipalDep` would have passed while
being wide open. A new test calls every non-public route **without a token and
insists on a 401**, so a route can only join the public set by being named in
`PUBLIC`, never by omission. That is what makes the agent-card sign-off mean
something.

**Next person should know**
- **Every turn currently starts with empty history.** `contextId` is echoed,
  never resolved — sessions are GGU-46, on a different branch. The resolution
  rule is already decided and unchanged (resolve against the subject or treat
  as unknown).
- **The stream is well-formed but not incremental.** `run_turn` returns a
  finished turn rather than yielding, so the events arrive in one burst.
  ADR-K D-19 wants per-surface streaming; making the loop a generator changes
  `a2a_service.py` only.
- **The body limit does not cover chunked encoding** (spec OD-6). `POST /` is
  the first route that reads the raw body itself, which makes a pre-existing
  middleware limitation load-bearing for the first time. Every envelope field
  is bounded, so what is unbounded is the read, not the response.
- **ADR-D is still `Proposed`.** This implements D-1, D-2, D-3, D-7 and D-9 as
  written. If ratification moves any of them, this surface moves too (spec
  OD-5). Treating a proposal as a decision silently would have been the easy
  mistake.

---

## 2026-09-19 — GGU-14 system prompt · spec `specs/backend/0009-prompt-fragments.md`

**Branch:** `feat/GGU-14_prompt_fragments`, stacked on GGU-36. Four deep.

**The gap.** Two halves existed and nothing joined them: `agent/prompt.py`
held the rules, `presentation/prompt.py` could render the projection registry
as text, and the turn loop imported the rules as a constant and **sent neither
catalogue**. The model was told it must pick a registered view and never told
which views exist.

They were never joined because they cannot be: `app.agent` may not import
`app.presentation` (asserted over the parsed source). A **service** is where
they meet, which is what `services/prompt_service.py` now is.

**Both catalogues are generated.** The views came from the registry already
(ADR-K D-14); the tools now do too. Registering a tool or a view is what
teaches the model about it — there is no list to forget to update. The rules
that stay hand-written deliberately **name no tool**: a rule saying "for a
why-did-it-move question call `compute_attribution`" reads better and is the
one line guaranteed to go stale, so a test asserts the rules mention no
registered tool name (spec OD-1).

**Also split:** `services/agent_telemetry.py`. The turn loop was already at the
150-line ceiling — the reviewer of GGU-47 flagged it — and observability is the
part that grows every time someone wants one more counter. It answers a
different question from the loop: what an operator gets to see.

**Verified**
- `make gate`: **527 tests**, 100 % branch coverage, pylint 10.00/10.
- Printed the real prompt: 2,585 characters, both tools and both views present
  with their option bounds, generated from the two registries.

**Next person should know**
- `AgentService` no longer imports `SYSTEM_PROMPT`; it receives the built
  prompt. The turn-loop tests inject their own, which is deliberate: the loop's
  job is to send whatever prompt it was given, and pinning the real text there
  would make every prompt edit break the turn-loop suite.
- The prompt is built **once at startup**, so adding a tool needs a restart —
  which is true of registration anyway (spec OD-4).

---

## 2026-09-19 — GGU-36 attribution tool · spec `specs/backend/0008-attribution-tool.md`

**Branch:** `feat/GGU-36_attribution_tool`, stacked on GGU-49 (which is itself
stacked on GGU-47). Three deep, which is the direct cost of shipping four
tickets before any of them merges — worth naming rather than hiding.

**The distinction the ticket turned on.** Flow A asks *"why did my portfolio
move this week?"*. The existing `attribution.waterfall.v1` projection walks
each holding's **unrealised P/L** — a comparison against what the position
*cost*. The question asks about what it was *worth seven days ago*. A holding
bought two years ago can be deeply profitable and have contributed nothing this
week. Conflating the two would have put a confidently wrong chart in front of a
reviewer, so this ticket adds a genuinely new domain computation rather than
reusing the one that was already there. Recorded as spec OD-3: whoever builds
the window projection gives it **its own id** instead of changing what `v1`
means.

**Code**
- `app/domain/attribution.py` — pure `attribute_window(portfolio, window,
  symbols)`. The totals are derived *from* the contributions, so the waterfall
  closes structurally rather than by rounding luck.
- `app/agent/tools/attribution.py` — the `compute_attribution` tool: a closed
  set of windows, an optional symbol filter, `extra="forbid"`, and output that
  is entirely `*Display` strings.

**Two facts that look like bugs and are not** (both pinned by tests, both in
the spec):
- **The money closes exactly; the shares do not.** `contribution` is a
  subtraction of exact amounts. `share` is a division, and division is inexact
  in any finite base — the shares land one unit in the last place away from 1.
  The chart is drawn from the contributions. A test says so, so nobody later
  "fixes" the closure by rescaling the ratios.
- **A share can exceed 100 % or go negative.** When holdings move in opposite
  directions, one contributed 132 % of the net move while another offset
  −32 %. That is what a waterfall shows and it is correct. Clamping it would
  misstate the answer.

**Verified**
- `make gate`: **518 tests**, 100 % branch coverage, pylint 10.00/10, no CVEs.
- Manual run of the tool: the 7-day window reports `-$3,175.95` / `-4.66%`,
  the bars sum to exactly `-3175.950000000000`, `closes()` is True, a filtered
  BTC+ETH 30-day run still closes against its own total, and two identical
  calls produce identical payloads.

**Next person should know**
- Windows are a **closed set** (`1d`/`7d`/`30d`), not a free-form duration.
  The seeded history is 90 days, so a free-form window would let the model ask
  for a year and get a silently truncated answer. The closed set makes the
  refusal explicit (spec OD-4).
- One test in the first draft asserted nothing meaningful (a `max()` over a
  constant, then `!= []`). The testing rule forbids exactly that, and it passed
  anyway — worth re-reading your own new tests for it, because a green suite
  will not tell you.

---

## 2026-09-19 — GGU-49 presentation layer · spec `specs/backend/0005-presentation-layer.md`

**Branch:** `feat/GGU-49_presentation_layer`, **stacked on `feat/GGU-47_agent_host`**
(see *Why this one is stacked* below). Built by a worktree agent in parallel
with GGU-47 and GGU-48.

**Code** — implements [ADR-K](../docs/adr/ADR-K-response-shaping.md) end to end:
`presentation/{registry,spec,fragments,displays,options,selection,prompt,contract,resolve,errors,sample,surfaces}.py`
plus two reference projections in `presentation/views/`, the `/v1/views`
catalog, `?view=` on a portfolio read, and the agent-facing render intent.

**Decisions worth knowing**
- **`views/` is auto-discovered** (`pkgutil.iter_modules`), not a hand-kept
  import list. The presentation rule blessed "one import line in the package
  `__init__`"; the ticket said *no* shared file may be edited to add a chart.
  Discovery satisfies both, and adding a chart is now literally one new file.
- **Options are shared across a multi-view request.** `?view=a&view=b` works,
  but `?view=attribution.waterfall.v1&top_n=3` is a **422** because the
  waterfall declares no `top_n`. Per-view namespacing would need a query-string
  interpreter, which ADR-K D-3 rejects; per-entry options belong to
  `POST /v1/view-renders` (D-18, out of scope).
- **`currency` is `Literal["USD"]`.** The backend invents no FX rate, so `EUR`
  is an honest 422 rather than a fabricated figure.
- **Selection stays additive**: each projection declares `fitness(portfolio)`
  and the rule ranks the registry — no `if/elif` on ids.
- **OpenAPI examples are rendered from the registry at operation level**, not
  hand-copied into `json_schema_extra`: a schema-level example would have to
  exist before the DTO class is complete.

**Why this one is stacked on GGU-47 rather than cut straight to `develop`.**
Built in parallel, the two tickets each created the piece the other also
needed. ADR-E D-2 allows exactly **one** formatting module and both had one;
the duplicate-code gate allows one AST helper for the boundary tests and both
had one. Landing them side by side would have merged that duplication into
`develop` and left someone to find it later. The integration commit on this
branch resolves it instead:

- `app/core/display.py` becomes the single `Decimal` → string boundary for both
  layers, carrying GGU-49's locale support and GGU-47's explicit sign.
  Quantities take a `trim` flag because a chart axis wants `"0.60000000"` and a
  sentence the model reads aloud wants `"0.6"`. `presentation/formatting.py` is
  gone.
- The locale table, the rounding and the digit grouping move to
  `app/core/locales.py` — *what kind of number this is* and *how digits are
  written in a place* are different questions, and together they broke the
  150-line budget.
- `tests/boundaries.py` is the one AST reader for the domain, agent and
  presentation suites; `tests/unit/import_graph.py` is gone.
- The portfolio provider is a **container** field, not a member of
  `AgentRuntime`: both the agent's tools and the projections read the same
  portfolios.
- **`app/api/deps` is now a package.** Merging both tickets' providers put the
  single file at 168 lines. Controllers still write
  `from app.api.deps import ...` unchanged, and services are still constructed
  in one place — it is one directory instead of one file.

**Verified**
- `make gate` after the rebase: **485 tests, 100 % branch coverage**, pylint
  10.00/10, interrogate 100 %, deptry clean, no CVEs.
- Manual run against the compose Postgres: two projections in one request;
  an undeclared option → 422 problem+json; `currency=EUR` → 422; no `view`
  named → the selection rule chose; unknown view → 404; another portfolio →
  404; no token → 401; `/v1/views` listed both projections with their options
  schemas; OpenAPI showed the `oneOf` with a `discriminator` and one example
  per member.

**A third duplication, found by auditing the merged result.** After both
branches were integrated, `total market value` was computed in **three**
places — the agent's `holdings_summary` tool and both projections — and the
`Portfolio` aggregate that owns the data exposed no total at all. None of them
was wrong, which is the point: they agreed only because three separate pieces
of code happened to be right. In a finance demo the agent says one of those
numbers out loud while a chart draws another, so *drift between them is the
most embarrassing failure available*. `Portfolio` now owns
`total_market_value()`, `total_cost_basis()` and `total_unrealized_pl()`, and
the three call sites read them. The residual "Other" bucket in the allocation
chart keeps its own sum — that one really is a chart concern.

Every pre-existing projection and tool test passed unchanged afterwards, which
is the evidence that the three implementations had been computing the same
figure.

**Next person should know**
- **`app/api/deps.py` no longer exists** — it is `app/api/deps/`. The
  architecture rule and `backend/CLAUDE.md` still name the file; they are
  correct about the *rule* (one place constructs services) and stale about the
  path. Fix the wording when you next touch them.
- Adding a chart is one file under `presentation/views/`. A test proves it:
  it defines `cash.runway.v1` inside the test body and finds it in the
  registry, in `GET /v1/views` and in the generated prompt fragments.
- `test_openapi_contract.py` was split — the projection assertions live in
  `test_openapi_projections.py` because the 150-line budget would not hold
  both. Same gate, two files, with a pointer in the original docstring.
- This entry and GGU-47's were written during integration, not by the building
  agents: the sandbox denies writes to `.claude/` inside an agent worktree.

---

## 2026-09-19 — Harness rule: the agent opens PRs, the TL merges them

**Harness only — no code change.**

**Decision (Lautaro, TL, 2026-09-19).** An earlier instruction in the same day
authorised the agent to merge its own PRs. It was withdrawn: **the agent never
merges**. Opening the PR is where the agent's part of the lifecycle ends. The
branch stays open, the Jira ticket stays **In Review**, and the merge happens
only after the TL explicitly confirms it — for `develop` exactly as for `main`,
and no matter how clean the gate is. When several PRs are waiting, the agent
reports the list and moves on to the next ticket rather than merging any of
them. Only when the TL names a PR (or says to merge them all) does the agent
merge and then move the ticket to **Done**.

**Changed**
- `.claude/rules/backend/sdd.md` — the rule itself, next to the ticket-status
  rule it completes; the `/feature` lifecycle line now reads "humans approve the
  spec at the start and the merge at the end".
- `.claude/commands/feature.md` — step 11 is now "stop at the open PR, never
  merge"; the wrap-up also reports the PRs still waiting on confirmation.
- Agent memory `pr-and-jira-workflow` updated with the same rule and the reason.

**Why it is written down here.** `Done` already meant merged; what was missing
was *who* merges. Without this, another developer's Claude reads a green gate as
permission to close the loop itself, which takes the review decision away from
the person who owns it.

**Next person should know.** PRs accumulate on purpose. A queue of open PRs
against `develop` is the expected steady state, not a backlog to clear.

---

## 2026-09-19 — GGU-46 session identity and isolation · spec `specs/backend/0004-session-identity.md`

**PR:** #13 · built by a worktree agent, rebased, re-gated and manually verified here.

**Re-baseline.** The ticket described the deleted ADK sample (`InMemorySessionService`,
client-supplied `contextId` as the session key) and asked for token verification
that PR #2 already shipped. What was actually missing — and what this delivers —
is **persisted conversations owned by the verified subject**.

**Code**
- Migration `0004`: `conversation_sessions` + `conversation_messages` (cascade,
  indexed on `(subject, created_at)` and `(session_id, created_at)`).
- `SessionRepository` scopes **every** query by subject; `SessionService` answers
  `NotFoundError` — never `AuthorizationError` — for another subject's id, so the
  API does not reveal that the session exists.
- Six fully documented REST operations under `/v1/sessions`, keyset pagination
  through `helpers/cursor.py`, shared query params in `api/params.py`, the whole
  router behind `require_feature("sessions.api")`.
- Audit events `session.create`, `session.read`, `session.list`, `session.append`
  carrying the session id as `target`.

**Mutation check (required for auth changes)**
- subject filter removed from `get_for_subject` → 4 isolation tests red;
- removed from `delete_for_subject` → 2 red; restored → 9 green.

**Next person should know**
- `DELETE` answers **404** for an unknown or foreign id rather than a blanket 204:
  idempotent on server state, and the isolation boundary stays testable from outside.
- Coverage loses a controller's lines **after** an `await` that crosses SQLAlchemy's
  greenlet bridge — `create_session`'s `Location` line is covered by a unit test with
  a faked service. Any future controller with post-`await` statements hits the same thing.
- Sessions live in the PostgreSQL the backend already owns; flagged as OD-1 against
  ADR-F D-1 for the TL.
## 2026-09-19 — GGU-48 continuous delivery · spec `specs/backend/0007-cd-pipeline.md`

**Branch:** `feat/GGU-48_cd_pipeline` → `develop`. Built in a worktree while the
GGU-49 and GGU-47 agents held `backend/src/app/presentation/` and
`backend/src/app/agent/`; this ticket deliberately took the one area with no
overlap (`.github/`, `infra/`).

**Code**
- `backend/src/app/core/release.py` — resolves `APP_RELEASE`, falls back to the
  packaged `__version__`. `bootstrap.py` now feeds it to `HealthService` and to
  the Sentry release, so a revision can say which build it is.
- `infra/delivery.tf` — Artifact Registry (digest-addressed, retention
  policies), the Workload Identity pool and provider **pinned to this GitHub
  repository**, and a deployer service account holding only
  `artifactregistry.writer`, `run.developer` and `serviceAccountUser` on the
  runtime identity.
- `infra/scripts/deploy_cloud_run.sh` — deploy with no traffic → require the
  revision's `Ready` condition → shift traffic → verify `/healthz` reports
  exactly the release → roll back on any failure.
- `.github/workflows/backend-cd.yaml` — publish, deploy, tag, report.

**Harness**
- `.claude/ship-gate.json` gains `infra.delivery-script` and
  `infra.credential-model`; the same two run in `pre-commit` and in the new
  `delivery-scripts` job of `infra-ci.yaml`, keeping the three in step as
  `.claude/rules/ci-conventions.md` §5 requires.
- `.pre-commit-config.yaml` gains `shellcheck` — the repository now has shell
  it depends on, so shell gets a linter.
- `infra-ci.yaml` was rewritten to the job/step naming contract (it predated
  the rule) and now ends in a `Report · …` summary like every other workflow.
- `CLAUDE.md` gains a delivery convention; `docs/diagrams/08` and `09` updated
  in this PR as `.claude/rules/diagrams.md` requires;
  `docs/compliance/CHANGE_MANAGEMENT.md` §7 rewritten around the automated
  record.

**Why the deploy is a shell script and not inline workflow YAML.** A rollback
path that has never executed is not a rollback path. As a script it runs
against a stub `gcloud` on `PATH`, so the whole sequence — including the
rollback — is exercised on a laptop in under a second. Inline YAML could only
have been proven by breaking a real deploy.

**What the `backend-reviewer` agent caught, and what changed because of it**

The first version was gate-green and wrong in four ways. All four are fixed
here; they are worth reading because three of them would only have shown up on
the first real deploy.

1. **The readiness probe could pass for the wrong revision.** It looked up the
   candidate revision's tagged URL and fell back to the service's public URL
   when the lookup missed — and the public URL still served the *previous*,
   healthy revision. A missed lookup therefore verified the old code and then
   shifted traffic to the unverified new one. An unresolvable revision is now a
   hard failure, covered by its own test.
2. **The probes could not have reached the service at all.** Ingress is
   `INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER`, so the `*.run.app` hostnames are
   unreachable from a GitHub-hosted runner and every deploy would have rolled
   itself back. The pre-traffic gate is now the revision's own `Ready`
   condition — which Cloud Run reports only after the startup probe on
   `/readyz` passes — and the post-traffic check goes to the load balancer
   domain (`PUBLIC_URL`), the only address that resolves from outside the VPC.
   Recorded as spec OD-5.
3. **The release tag could never be created.** The workflow granted
   `contents: read` and then POSTed a ref, swallowing every error as "already
   exists". The deploy job now has `contents: write` and distinguishes a 422
   from a real failure.
4. **One provider and one deployer variable cannot serve two projects.**
   `delivery.tf` creates a pool, a provider and a deployer *per environment*,
   but the workflow read repository-level variables and only branched on the
   project id — so a `main` run would have authenticated as staging and pushed
   into the production registry. A `settings` job now resolves the whole
   per-environment set once and **fails naming the missing variable** instead.

Also from that review: the release is read through `Settings.app_release`
rather than `os.environ` (the architecture rule allows `os.environ` only in
`core/config.py`); the release comparison is an exact match on the parsed
`version` field instead of a substring, so `0.1.0` no longer "matches"
`0.1.0+stale`; production federation additionally requires
`assertion.ref == refs/heads/main`; `run.tf` declares `ignore_changes` on the
image and the traffic split so a later `terraform apply` cannot undo a
rollback (OD-6); `APP_RELEASE` is documented in `env.example` and compose; and
the report job now fails on `skipped`, so a rejected production approval is not
reported green.

**Verified**
- `make gate`: 266 tests, 100 % branch coverage, pylint 10.00/10, no CVEs.
- `bash infra/scripts/tests/test_deploy_cloud_run.sh`: 36 passed, covering all
  nine paths including deploy failure and an unidentifiable revision.
  **Mutation check** — removing `shift_traffic "${previous}"` from `rollback()`
  turned exactly 5 assertions red; restored → 36 passed.
- `bash infra/scripts/tests/test_wif_conditions.sh`: 5 passed.
- `terraform fmt -check -recursive` clean; `terraform validate` → *Success!*
- `shellcheck` clean on all delivery scripts.
- Container run with `APP_RELEASE=0.1.0+a1b2c3d` → `/healthz`
  `{"status":"ok","version":"0.1.0+a1b2c3d"}`; without it → `"0.1.0"`;
  `/readyz` ready; uid still 10001.

**Next person should know**
- **The pipeline is merged but has never run**: the GCP projects do not exist
  until GGU-29 applies Terraform. AC-1, AC-2 and the live halves of AC-4/AC-5
  are proven here by the script tests and `terraform validate`, not by a
  deploy, and the PR says so rather than implying otherwise.
- After GGU-29, set the repository **variables** (not secrets) from the
  Terraform outputs. Everything except `GCP_REGION` is suffixed per
  environment, because each environment has its own pool, provider and deployer:
  `GCP_PROJECT_ID_*`, `GCP_WIF_PROVIDER_*`, `GCP_DEPLOYER_SA_*`, `PUBLIC_URL_*`.
  Then add the required reviewer to the `production` GitHub Environment — that
  reviewer *is* AC-2; the workflow only declares the environment.
- A gate-green delivery pipeline proves very little. Everything that mattered
  in this ticket was found by reading the failure paths, not by running the
  suite; budget review time accordingly on anything that touches deploys.
- `cleanup_policy` is `cleanup_policies` in the google provider v6. The first
  spelling validates as an unsupported block, which is how it was caught.
- Terraform provider downloads need network access the sandbox denies; run
  `terraform init` outside it.
## 2026-09-19 — GGU-28 open-source readiness · spec `specs/repo/0001-open-source-readiness.md`

**Branch:** `docs/GGU-28_open_source_readiness` → `develop`. Documentation and
one developer command; no application code changed.

**The finding that shaped it.** The repository had **no `README.md` at all** —
a public reference application whose audience is Google's reviewers, with no
entry point. It also had no `NOTICE`, no architecture document, no contribution
guide and no issue templates.

**Added**
- `README.md`, `NOTICE`, `docs/ARCHITECTURE.md`, `CONTRIBUTING.md`,
  `.github/ISSUE_TEMPLATE/{bug_report,feature_request,config}`.
- `backend/scripts/mint_dev_token.py` and `make token`. Not cosmetic: every
  route except the health ones is authenticated, so without it the README's
  clone-and-run promise was false — a fresh clone could not call anything.
- `specs/repo/` as a spec area for repository-level work, registered in
  `specs/README.md`.

**The decision worth keeping.** The README describes **what is built, not what
is planned**, and says so in its second paragraph: the backend is real, the
Flutter client is still Google's upstream `restaurant_finder` sample, the
delivery pipeline has never run, and the market data is invented. A reviewer
who discovers the Flutter gap by failing to run the app trusts nothing else in
the repository, so the gap leads rather than hides. `docs/ARCHITECTURE.md`
ends in a "Known gaps" table naming the ticket that closes each one — which now
has to shrink as GGU-3, Epic 1, GGU-29 and GGU-22 land. **Leaving that table
stale is the main risk this change creates.**

Per-file Apache headers were declined on backend sources (spec OD-2): `LICENSE`
plus `NOTICE` satisfies the licence, the upstream client files keep their
Google headers as required, and a 13-line header on files capped at 150 lines
would consume the budget it is meant to protect.

**Verified**
- The README's own commands, run for real against a **clean** database:
  compose up, `make token`, `GET /v1/me` → 200 `{"subject":"alice",...}`; the
  same call with no token → 401 problem+json; `/healthz` and `/readyz` 200
  unauthenticated; `/openapi.json` complete.
- `gitleaks` over the **full history** — 71 commits, ~5 MB, **no leaks**.
- `make gate` green: 262 tests, 100 % branch coverage, pylint 10.00/10.

**Next person should know**
- The shared compose database is at Alembic revision `0004` from the GGU-46
  branch, which `develop` does not have yet — a container built from `develop`
  refuses to start against it ("Can't locate revision identified by '0004'").
  Use a throwaway database when verifying a branch that predates it.
- `make token` is local only and refuses to run without `AUTH_JWT_SECRET`
  rather than inventing a default. It cannot mint anything production would
  accept, because production verifies RS256 through OIDC.
## 2026-09-19 — GGU-47 agent host · spec `specs/backend/0006-agent-host.md`

**Branch:** `feat/GGU-47_agent_host` → `develop`. Built by a worktree agent in
parallel with GGU-49 (presentation) and GGU-48 (delivery), with
non-overlapping file ownership agreed up front.

**Why the ticket existed at all.** The board had tickets for the prompt
fragments (GGU-14), the deterministic tools (GGU-36–39) and the transport
(GGU-3), but nothing owned the piece that ties them together. The deleted ADK
sample provided it for free; the FastAPI baseline does not. Without it every
tool ticket would have merged as an unreachable pure function.

**Code**
- `core/model.py` (conversation DTOs), `core/display.py` (the single
  `Decimal` → string boundary), `core/protocols.py` gains `ModelClient`.
- `agent/{contracts,registry,prompt}.py` and `agent/tools/holdings_summary.py`
  — tools register from their own module, so adding one never edits a shared
  file. That seam is what GGU-37/38/39 depend on.
- `infra/model/{payload,gemini_client,null_client,factory}.py` — the Gemini
  adapter behind the Protocol, plus a deterministic `NullModelClient` wired
  exactly like the existing `ErrorReporter`/`NullErrorReporter` pair.
- `services/agent_service.py` (the turn loop) and `services/agent_tools.py`
  (tool execution and failure masking, split out to stay inside the budget).

**Decisions worth knowing**
- **httpx, not the `google-genai` SDK.** No new dependency, no new pip-audit or
  deptry surface, and the adapter mirrors `JwksKeyResolver`, a pattern already
  proven in this codebase. Swapping to the SDK later is one module.
- **The render intent is declared, not resolved.** `agent/contracts.py` defines
  only `{view, options}` (ADR-K D-11). Validating it against the projection
  registry and falling back on rejection is ADR-K D-12 and belongs to GGU-49 —
  which is why the two tickets could run in parallel at all.
- **One formatting module.** `core/display.py` sits in `core` because it is the
  only place both `app/agent` and `app/presentation` may import (ADR-E D-2).
  **The presentation layer must reuse it rather than add a second formatter.**
- **The iteration bound counts model calls, not tool calls** (default 4: one
  plan plus three corrections). On exhaustion the turn answers a fixed message
  and sets `truncated=True`, rather than emitting half a sentence.
- **A misbehaving tool never fails the turn.** The model receives
  `{"error": ...}` and another iteration; only the exception object reaches the
  `ErrorReporter`. An unknown tool is not reported at all — it is the model's
  mistake, not ours.
- `AgentRuntime` groups `model`/`tools`/`portfolios` in `api/container.py`:
  three more singletons would have pushed `Container` past pylint's attribute
  limit.

**Verified**
- `make gate`: 348 tests, 100 % branch coverage, pylint 10.00/10, interrogate
  100 %, deptry clean, no CVEs.
- **Mutation check** (required whenever error masking changes): removing the two
  `except` clauses in `gemini_client.py` turned 9 tests red; restored → 32
  green.
- Manual run of a full turn against `NullModelClient` with a tool call: the
  tool result was fed back to the model on the second call, the turn answered
  with the pre-formatted figures, and the telemetry line carried
  `model`/`outcome`/`duration_ms`/`iterations`/`tool_calls` and **no** prompt,
  answer or subject.

**What review changed.** The `backend-reviewer` agent approved it with no
blockers and eleven should-fixes. Four were rule violations and are fixed here:
`backend/docs/SECURITY.md` still described the model key as living in a "future
spec", `backend/docs/OBSERVABILITY.md` did not list the new metric or events,
`docs/diagrams/01-system-context.md` still drew Gemini as "(planned — GGU-47)"
in the ticket that ships it, and the spec was `Draft` and missing from
`specs/README.md`. The remaining seven are recorded as **OD-7 … OD-12 in the
spec** rather than fixed here, each with the ticket that should fix it. The one
worth reading is **OD-7: the Gemini wire format has never met the real API** —
every test runs against stubs we wrote, so 100 % coverage proves the code
matches *our assumption* of the format. GGU-3 carries the first live call and
should treat a mapping fix as expected.

**Next person should know**
- **There is no HTTP route yet.** `api/v1/`, `router.py` and the OpenAPI
  document are untouched by design; `get_agent_service` and `get_tool_context`
  wait in `deps.py` for GGU-3 to expose the A2A surface (ADR-J D-2).
- The default model id is `gemini-3.8-flash`, the only pin recorded in the repo
  (ADR-D D-4). Nothing depends on it; `GEMINI_MODEL` overrides.
- `tests/unit/import_graph.py` now holds the shared AST helpers that the domain
  and agent boundary tests both use — pylint's duplicate-code check forced the
  extraction, and the presentation layer's boundary test should reuse it too.
- This entry was written during integration, not by the building agent: the
  sandbox denies writes to `.claude/` inside an agent worktree. Budget for that
  when delegating.

---

## 2026-09-19 — GGU-5 portfolio domain · spec `specs/backend/0003-portfolio-domain.md`

**PR:** #12 · **Built by a worktree agent**, integrated and verified here.

**Code**
- `src/app/domain/` — 16 modules, each ≤150 lines: `money` (Decimal end to end,
  float rejected at the boundary), `terms` (long = **strictly more than 365 days**,
  leap year asserted), `lots`, `holdings`, `transactions`, `prices`/`history`
  (deterministic **90-day** daily series ending on the current price),
  `market` (curated reference — the deleted `crypto_data.json` is gone and the
  domain is now the **single source of price**), `invariants` (exact Decimal
  equality; weights within 0.0001), `portfolio`, `seed`, `provider`.
- `PortfolioProvider` Protocol + in-memory implementation: portfolios are
  per-subject and `as_of` is fixed at first access, so a lot cannot flip term
  mid-demo. No `datetime.now()` anywhere — a test parses the AST to prove it.

**Decisions recorded in the spec**
- OD-1 (blocked GGU-5): 90-day window, answered by GGU-36's owner in Jira.
- `Portfolio` is a frozen dataclass, not a pydantic model — a `validate()` read
  method would shadow pydantic's deprecated `BaseModel.validate`.
- `price_series`: `min(window, 89)+1` points, truncates above history,
  `window=0` → 1 point, negative → `WindowOutOfRangeError`.
- `provider.get` **seeds** instead of raising for an unknown subject: a demo
  session must not open on an error, and that is what fixes `as_of`.
- Divergence from ADR-C D-7 (stdlib logging): the provider uses
  `app.core.logging` because this backend configures structlog in `bootstrap`;
  D-7 was written for the deleted `backend_python/`.

**Next person should know**
- The shared dev database was stamped at revision `0004` by the GGU-46 worktree
  while this branch only has `0001`–`0003`; run the suite with testcontainers
  (the default) or re-create the local volume.
- `docs/specs/GGU-5/domain-contract.md` (written before the rewrite) is
  superseded by spec 0003 §8 — it should be marked as such when GGU-46 lands.

---

## 2026-09-19 — REST + OpenAPI contract, quality tooling, CI redesign

**Decisions (Lautaro):** every endpoint strictly RESTful and *exhaustively*
documented in Swagger; add every tool that keeps the code impeccable and run
them in a pre-commit hook; make CI cheap and readable; all PRs go to `develop`.

**Code**
- `api/openapi.py` — one place for problem responses, tag metadata and the API
  description; controllers compose from it instead of repeating `responses=`.
- Every operation now carries `operation_id`, `description`, `tags`, full
  `responses` (problem+json per status) and examples; every DTO field and query
  parameter has a description, an example and a bound.
- `GET /v1/me/audit` → **`GET /v1/me/audit-events`** (plural resource noun).
- `tests/unit/api/test_openapi_contract.py` makes the rule enforceable: a route
  without summary/description/operation_id/tags/responses fails the gate.

**Harness**
- `.claude/rules/backend/api-design.md` (REST semantics, OpenAPI completeness, DRY).
- `.claude/rules/ci-conventions.md` (where a check belongs, job/step naming,
  cost rules, "change one → change all three").
- `make quality` = xenon · vulture · interrogate (100 % docstrings) · deptry ·
  pylint (duplication + design limits) · codespell, wired into `make gate`,
  `.pre-commit-config.yaml` and CI.
- `.pre-commit-config.yaml` rewritten: hygiene hooks (incl. `check-added-large-files`
  and `no-commit-to-branch main,develop`), gitleaks, ruff, codespell, actionlint,
  `terraform_fmt`, local typecheck/budget/quality/unit-tests, and `make gate` on pre-push.
- `backend-ci.yaml` rewritten as four readable jobs (Quality · Tests · Security ·
  Container) plus a `Report` job writing a table to the run summary; PostgreSQL as a
  **service container** instead of testcontainers; `image` needs the cheap jobs.
- Branch model: `develop` is the integration branch, `main` release-only.

**Next person should know**
- `pre-commit install && pre-commit install --hook-type pre-push` once per clone.
- Adding an endpoint without full OpenAPI metadata now fails `make gate`, not review.
- `starlette` became an explicit dependency (deptry caught the transitive import).

---

## 2026-09-19 — Audit remediation: compliance corpus, admin MFA, retention purge

**PR:** https://github.com/somnio-projects/finance-google-a2ui/pull/2 (reviewer `mcampbell-somnio`).

**Trigger:** first full Somnio CLI audits on the foundation — `soc2-audit`
40/100, `iso27001-audit` 64/100, `python-best-practices` 88/100 (the earlier
`security-audit` 98 measured only technical controls). Lautaro's standing rule:
every audit > 90 before the PR.

**Code**
- `JwtClaims` / `JwksDocument` pydantic boundary models; `core/dto.py::from_row`
  (corrupt row → typed 503); `FeatureFlagCache.get` and `JwksKeyResolver.key_for`
  are pure queries; `Final` constants; `create_app` split; fixture/`autospec`/ids
  fixes (PR #2).
- **Admin MFA**: `Principal.auth_methods` from the `amr` claim, `Principal.is_mfa`,
  `Settings.admin_mfa_required` (default = production), enforced in
  `FeatureFlagService._require_admin`.
- **Retention**: `AuditRepository.purge_older_than`, `AuditService.purge_expired`,
  `app/jobs/purge_audit.py` (`python -m app.jobs.purge_audit`, `make purge-audit`), `AUDIT_RETENTION_DAYS=400`.
- **IaC** (`infra/`, Terraform ~> google 6): the CLOUD_SERVICES §3 topology as code —
  validated locally and in `infra-ci.yaml` (fmt · validate · trivy config); **not
  applied** (no GCP project until GGU-29). Closes the SOC 2 Family F evidence gap
  honestly: the controls exist as reviewed code, status "apply pending".
- `backend-reviewer` round 2 (final tree) FLAGGED 2 blockers + 7 should-fix, all
  addressed: `audit_events.target` column (migration 0003) so `action` stays
  `<domain>.<verb>` and 100-char flag keys no longer overflow `String(64)`;
  `feature_flag.list` audited; `httpx2` justified in `pyproject.toml` (Starlette's
  TestClient needs it); purge job moved to `app/jobs/purge_audit.py` (typed,
  covered, run as a module — the image ships `src/app` only); spec 0002 aligned (MFA, target, test
  names, mutation check); docs synced; branch-protection claims corrected with
  the exported ruleset (`docs/compliance/evidence/`, enforcement disabled today);
  `Edit` deny added for the merged migration 0002.
- Run 4 of `python-best-practices` (90) → basedpyright now also reports
  `Any`/`ExplicitAny`, unknown parameter/lambda types, private usage and
  uninitialised instance variables (only 2 fixes needed); `KeyResolver` split
  into `ensure_fresh()` + `key_for()`; `AuditService`/`IdentityService`
  constructors keyword-only; integration `session` fixture disposes in `finally`.
- `api/router.py` documented as the single route registration point;
  `docs/ADDING_AN_ENDPOINT.md` recipe + controller template (Lautaro: "routes
  ready to declare endpoints with the harness next iteration").

**Harness / repo**
- `docs/compliance/` — 27 policy/runbook documents + `isms/` (scope, SoA with all
  93 Annex A controls, objectives, document control, internal audit program,
  management review, CAPA log, competence records). Owner/approver/version
  headers; honest status words (pentest and DPAs are *planned*, not claimed).
- `.github/CODEOWNERS`, `pull_request_template.md`, `scheduled-scan.yaml`
  (weekly pip-audit + SBOM, Trivy SARIF, gitleaks → issue on failure), Semgrep
  `sast` job in `backend-ci.yaml`; root `SECURITY.md`, `CODE_OF_CONDUCT.md`,
  `CONTRIBUTORS.md`, `CHANGELOG.md`.
- First **restore drill executed** against the compose database (pass, ~1 s) —
  `docs/compliance/RESTORE_DRILL_LOG.md`.

**Verified locally before the PR (2026-09-19)**
- `make gate`: 177 tests, 100 % branch coverage, basedpyright strict (+6 rules), pip-audit clean.
- Mutation checks: `require_feature` gate (2026-09-18), MFA branch of `_require_admin` → red → restored green.
- `docker compose up --build` with `backend/.env` from the template: migrations at `0003`, uid 10001 read-only, 401/200 identity, flag toggle 200 → 404 → 403 → 200, 100-char key with `target`, `feature_flag.list` audited, `python -m app.jobs.purge_audit` runs in the image.
- Restore drill #1 (pg_dump → scratch DB → compare → drop) passed — `docs/compliance/RESTORE_DRILL_LOG.md`.
- `infra/`: `terraform validate` OK, `trivy config` 0 findings.
- Somnio CLI: security 98 · python-health 91 · python-best-practices 91 · soc2 40→78→93 (with IaC) · iso27001 64→86→92. **All five > 90.**

**Next person should know**
- Policies are approved by merge; the management review #1 is asynchronous in
  PR #2 by design — from #2 it is a meeting.
- Local admin tokens for a production-like run need `"amr": ["pwd","otp"]`.
- `make purge-audit` needs `DATABASE_URL`; in production it is a monthly job
  (GGU-29).
- `backend-reviewer` should check that a new column/DTO field appears in
  `docs/compliance/DATA_CLASSIFICATION.md` §2.

---

## 2026-09-19 — Feature flags for endpoints · spec `specs/backend/0002-feature-flags.md`

**Decision (Lautaro):** endpoints must be switchable on demand without a deploy.

**Code**
- `feature_flags` table (revision `0002`), `FeatureFlagRepository`,
  `FeatureFlagCache` (TTL, in the `Container`), `FeatureFlagService`
  (env kill-switch → cache → DB → default; `admin` scope for writes; audit
  event `feature_flag.update` with `target=<key>` + `feature_flag.toggled` metric).
- `api/feature_gate.py::require_feature(key, default=)` — route dependency
  answering 404 `feature-disabled`; `/v1/me/audit` is the first gated route.
- Admin API `GET/PUT /v1/admin/feature-flags[/{key}]`; settings
  `FEATURE_FLAGS_CACHE_TTL_SECONDS`, `FEATURE_FLAGS_FORCE_DISABLED`.
- Repositories now translate `OSError` (asyncpg connection refused) as well as
  `SQLAlchemyError` — a flag read against a down database falls back to the
  gate default instead of a 500.

**Harness**
- `backend/docs/FEATURE_FLAGS.md`; `backend/CLAUDE.md` gets the flag rule;
  `specs/README.md` index; compose/env.example variables.
- **Env policy (Lautaro, 2026-09-19):** `docker-compose.yml` carries only the
  topology; the backend service loads `backend/.env` through `env_file`
  (required — `cp backend/env.example backend/.env` once per clone). Env files
  live inside each solution and are git-ignored (`**/.env`, `**/.env.*`); the
  agent cannot create them (permission deny), a human copies the template.
  Compose stays backend-only until frontend work starts.

**Next person should know**
- Dark-launch a new endpoint with `default=False`; an admin flips it on.
- The gate runs before the route's own auth, on purpose (a disabled route
  does not advertise itself); the flag service never raises.

---

## 2026-09-18 — Backend foundation (FastAPI) · spec `specs/backend/0001-backend-foundation.md`

**Decision (Lautaro, TL backend):** replace the inherited Google ADK sample
(`backend_python/`) with a Somnio-standard FastAPI service in `backend/`. This
diverges from Jira GGU-45/ADR-C (`src/a2ui_crypto_market` packaging move) — the
tickets will be re-baselined against this foundation.

**Code**
- `backend/` created: layered FastAPI app (`api → services → repositories →
  models`, `bootstrap.py` composition root), Postgres via SQLAlchemy async +
  Alembic, bearer-token auth with pluggable verifiers (HS256 `jwt`, OIDC/SSO
  `oidc` via JWKS), audit trail table, RFC 9457 errors, request-id / security
  headers / body-limit / rate-limit middleware, Sentry behind an
  `ErrorReporter` Protocol, structlog JSON.
- 100 % branch coverage: unit suite with fakes, integration suite on a
  testcontainers PostgreSQL through real migrations.
- `Dockerfile` (non-root, read-only) + root `docker-compose.yml` (db + backend).
- `backend_python/` deleted.

**Harness**
- Root `CLAUDE.md` rewritten as an index; `backend/CLAUDE.md` is the backend
  operating manual.
- New rules `.claude/rules/backend/{architecture,security,testing,sdd}.md`
  (path-scoped); Python rules re-pointed from `backend_python/*.py` to
  `backend/**/*.py`.
- `.claude/settings.json`: PostToolUse hook `post-edit-check.py` (ruff +
  basedpyright + 150-line budget on edited backend files), `uv`/`docker
  compose`/`make` allowed, stale `pnpm` allows removed; the generated
  `claudeFlow`, `statusLine` and `model` blocks were dropped (unused tooling),
  the sandbox `excludedCommands` narrowed to `gh`/`gcloud`/`docker`/`open`/
  `osascript`; `Edit` denied on the merged Alembic revision and on `uv.lock`
  (new revisions are still creatable).
- `backend-reviewer` first pass (2026-09-18) FLAGGED 2 blockers + 7 should-fix;
  all addressed in the same PR: gitleaks allow on the fixture literal, 413/429
  via `problem_response` (request_id/instance), rate limiter keyed per IP
  **and** per token (rotating garbage tokens no longer buys budget), `Settings`
  rejects `*` in CORS and `*` hosts in production, readiness status decided in
  the DTO (no branching in the controller), `Principal` moved to `core/`,
  `main.py` no longer omitted from coverage, `make gate` now includes `audit`.
- `.claude/agents/backend-reviewer.md`, `.claude/commands/{feature,spec}.md`.
- `.claude/ship-gate.json` populated (6 backend commands = CI = `make gate`).
- `specs/` created (README, TEMPLATE, first spec); `docs/DEV_HARNESS.md`.
- CI: `.github/workflows/backend-ci.yaml` (gate + gitleaks + docker build).

**Verified locally before the PR**
- `make gate`: 121 tests, 100 % branch coverage, ruff/basedpyright/budget clean.
- Mutation checks: auth dependency and rate limiter disabled → the
  identity/middleware tests went red; restored → green.
- `docker compose up --build`: `/healthz` 200 with security headers, `/readyz`
  ready, `/v1/me` 401 problem+json without token and 200 with a token, audit
  row persisted, container uid 10001 on a read-only filesystem,
  `alembic check` reports no drift.

**Next person should know**
- `env.example` has no leading dot on purpose (the deny rule `**/.env.*`
  blocks the agent from creating templates too).
- List settings (`CORS_ALLOWED_ORIGINS`, `TRUSTED_HOSTS`) are comma-separated,
  not JSON — `CsvList` (`NoDecode`) in `core/config.py`. The compose stack
  caught this; a unit test now pins it.
- Async pytest fixtures use function loop scope; a session-scoped async
  fixture with asyncpg fails with "attached to a different loop".
- uv on this Mac needs `UV_LINK_MODE=copy` inside the sandbox; the Makefile
  exports it.
- Flutter gate is still a `_candidates` entry in `ship-gate.json` until
  GGU-45/GGU-1 land.

---

## 2026-09-20 — GGU-29: the dev environment, applied for real (#29, #31, #32)

**Specs:** `specs/infra/0001-dev-environment.md` (new, §10b is the interesting part)

**Code.** A POC-sized `dev` environment: one local, `ephemeral = var.environment
== "dev"`, derives every durability/exposure/cost decision, so `dev.tfvars`
cannot make dev expensive and `production.tfvars` cannot make production cheap.
Staging was dropped rather than built and left idle. CD retargeted: `develop` →
dev behind a **real `needs: [ci]` edge** (backend-ci gained `workflow_call` and
runs as backend-cd's `ci` job) rather than a `workflow_run` trigger that has to
remember to inspect `conclusion`.

**Harness.** `test_dev_environment.sh` (34 assertions). `.claude/ship-gate.json`
gained `infra.dev-environment`; ci-conventions §5 now names the three runners.

**What actually matters here: six defects, none of which any check in this
repository could have caught.** Every one lives in the gap between two things
that were each internally consistent, and nothing read both:

1. Cloud SQL `edition` unset → defaulted to ENTERPRISE_PLUS, which rejects
   every shared-core tier. `terraform plan` accepted it: **plan validates the
   schema, not the API's compatibility rules.** Spec OD-2 had predicted the
   tier question and recorded a fallback that would have failed identically.
2. `sqladmin.googleapis.com` does not accept a service-level audit config —
   wrong one of two real API names. The compliance corpus claimed those logs;
   the claim was unapplyable.
3. Secret Manager's service agent: created and used inside one apply, and IAM
   could not see it yet. A 30 s wait is in the config, not in a runbook step.
4. **`ENVIRONMENT=dev` was not a value the backend would accept.** Terraform
   passes `var.environment` straight through; `Environment` in `config.py`
   listed local/test/staging/production. The container would have died at
   startup, after everything else was built.
5. A mounted-but-empty optional secret arrives as `""`, not absent, so the
   factories that branch on `is None` would have built `sentry_sdk.init(dsn="")`
   and a keyless Gemini client.
6. **Google's edge intercepts the exact path `/healthz` on `*.run.app`** and
   never delivers it to the container. Liveness is now `/health`.

**Next person should know**

- **`terraform validate` cannot see Python and `make gate` cannot see
  Terraform.** Defect 4 is the canonical example, and the fix is the pattern:
  `test_dev_environment.sh` now reads `variables.tf` *and* `config.py` and
  compares the environment names. When a fact is declared on both sides of
  that wall, the test belongs in the shell suite — it is the only place that
  can see both.
- **A deployment hands the application things no test ever hands it.** Defects
  4 and 5 are both that shape. An empty secret and an unknown environment name
  are not exotic; they are what a real mount and a real env var look like.
- **`/healthz` is unusable on Cloud Run's run.app domain.** Proven with two
  controls from two networks (see the PR #32 body). Six alternative paths were
  probed before choosing `/health`. Do not "fix" this back.
- **Read the first apply, not just the first plan.** The spec told the reader
  to read the plan. The plan was clean and five of the six defects were still
  waiting. Plan is necessary and nowhere near sufficient.
- **`gcloud storage buckets describe --format=json` reports versioning under
  `versioning_enabled`**, not `versioning`. A wrong key reads as "off" and
  invites you to re-enable something that was already on.
- Secret Manager **rejects an empty payload**, so a deliberately-absent secret
  is stored as a single space and labelled `state=intentionally-blank`. This is
  why the blank-is-unset validator strips whitespace instead of comparing to
  `""`.
- **Still open, and it is the only thing between dev and a green pipeline:**
  the Cloud Run service has no `run.invoker` binding, so it answers 403 to any
  caller without a Google identity — including the pipeline's own post-deploy
  probe, which is unauthenticated by contract. `iam.tf` carries the dev-only
  binding and it plans clean; applying it is an exposure decision left to the
  TL (OD-4). The rollback path was exercised for real by this failure and
  worked: traffic was restored to the previous revision.

---

## 2026-09-20 (cont.) — persistence, delivery, and four claims nothing checked (#35, #37, #38, #39, #40, #41)

**Specs:** `specs/backend/0020-portfolio-persistence.md`

**Code.** The portfolio left process memory for PostgreSQL. Delivery became a
button (`workflow_dispatch` only — merging deploys nothing). Migrations run as
a Cloud Run job *before* the traffic shift. Five GitHub Actions bumped, and
Dependabot pointed at `develop`. The views endpoint now accepts the options
its own catalog advertises.

**The pattern, again.** Every defect found today was a property someone had
written down and nothing enforced. Listing them together because the shape is
more useful than any one of them:

| Claim | What was true |
|---|---|
| `dev` is a deployable environment | `Environment` in `config.py` had no `dev`; the container would have died at startup |
| the compliance corpus's Cloud SQL audit logs | `sqladmin` does not accept a service-level audit config — the claim was *unapplyable* |
| `/healthz` is the liveness endpoint | Google's edge intercepts that exact path on `*.run.app`; it never reached the container |
| migrations run on deploy | nothing ran them anywhere — `/readyz` proves the connection, not the schema |
| the catalog's options are the endpoint's options | nine advertised options answered 422; four of six projections unreachable from the client |
| every operation documents an example | `POST /` — the A2A surface — had none, and it is the route a client is most written against |
| `ship-gate.json` == CI | CI linted `tests/*.sh`, the gate did not; my own shellcheck finding reached `develop` |

**Next person should know**

- **Verify from outside the thing you are verifying.** Four of the seven above
  were found by sweeping the *deployed* service or the *running* stack, not by
  reading code. The sweep that found the options gap was generated from
  `/v1/views` so it could not miss one; had I written the list by hand I would
  have written the same nine names the endpoint already knew.
- **A contrast isolates a defect faster than a stack trace.** `POST
  /v1/view-renders` served the identical options with a 201 while `?view=`
  answered 422. That one comparison moved the bug from "the projections are
  broken" to "the query model is stale" in a single request.
- **Two of my own verifications lied before they told the truth.** A schema
  probe passed its Python through `gcloud --args`, which splits on commas, so
  the container ran `import asyncio` and exited 0 — a pass with no output. And
  an error-path test raised `IntegrityError` from `execute`, where the *read*
  handler caught and translated it, so the write path was never exercised. A
  green check is evidence only if it could have been red.
- **A real database finds what a fake never will.** An `IntegrityError` aborts
  the whole PostgreSQL transaction, so the loser of the seeding race could not
  re-read the winner until `replace` was wrapped in a SAVEPOINT. No fake
  repository has that behaviour to imitate.
- **`NUMERIC(38,18)` changes a `Decimal`'s string form.** Returning the freshly
  seeded object made a session's *first* answer differ from every answer after
  it, which ADR-K D-20 forbids. `get` re-reads after seeding. The integration
  flow test caught it — written months before persistence existed.
- **Dependabot needs `target-branch`.** Without it, it opens against the
  repository default (`main`), and this project merges to `develop`. Five PRs
  sat unmergeable-by-construction for weeks with nothing saying why.
- **`/healthz` is unusable on run.app.** Proven with two controls from two
  networks. Do not "fix" it back.

---

## 2026-09-20 — ADR-F D-4: recording what replaced the single-instance constraint

**Documentation only.** No code, no Terraform, no threshold moved.

**What was wrong.** ADR-F D-4 required Cloud Run to run
`min-instances=1, max-instances=1` because session and portfolio state lived in
process memory. Two things had happened to it: no environment ever ran 1/1
(production 1/4, staging 0/2, dev 1/2 derived), and the reason had been removed
— sessions in PostgreSQL since GGU-46, the portfolio since spec `backend/0020`.
The divergence was known and lived in `specs/infra/0001` §11 and three Jira
comments, which is not where anyone reads a constraint.

**What changed.** D-4 is struck and superseded by D-7 (scaling out is capacity,
not correctness — the unique constraint on `portfolios.subject` is the
load-bearing part), D-8 (`min-instances = 1` survives as a **cost** decision for
the 2026-09-28 demo and must never be cited as a safety property) and D-9 (the
two in-process caches D-4 was silently bounding: the fixed-window rate limiter
and the feature-flag TTL cache). D-1, D-2 and D-5 are annotated as overtaken in
fact; D-3 is annotated as **resolved — the seam it bought was spent**. The
amendment is **Proposed**: ratification is the TL's.

**Also.** Diagrams 07 (three portfolio tables, migration 0005, and the reason
they exist) and 08 (dev is 1–2 instances, not scale-to-zero). `specs/README.md`
deduplicated (0003, 0006, 0013 were each listed twice) and completed (0004,
0007 and 0020 had no row at all). Two `ADR-F-*.md` links in specs `0007` and
`0020` pointed at filenames that do not exist.

**Next person should know**

- **The registry gained a status.** `Accepted · D-n superseded by D-m` is now in
  `docs/adr/README.md`'s vocabulary, for when the context changes under one
  ruling rather than under a whole record. Strike the old `D-n`, never delete
  it — code and specs cite rulings by number and those citations must resolve.
- **A number that outlives its reason is worse than no number.** `min-instances
  = 1` is unchanged in the Terraform and means something completely different
  from what it meant two days earlier. D-8 exists only so nobody re-derives the
  old reason from the surviving value.
- **Removing a constraint un-bounds whatever was quietly leaning on it.** D-4
  was also the only thing making the in-process rate limiter a hard ceiling. It
  is now `N × limit` across `N` instances. Spec `0001` OD-2 had already named
  the Redis adapter as the fix "when `max-instances > 1`"; that condition is
  true today and nothing announced it.
- **`specs/infra/0001` §11 is the pattern to avoid.** Three real divergences
  were found and written into a spec section titled "not fixed here". Two of
  them are closed by this change, four days later, because someone was asked to
  look — not because the record surfaced them.

---

## 2026-09-20 — ADR-B D-4: a revocation check that was never built (GGU-87)

**Documentation only.** No code, no dependency, no threshold moved.

**What was wrong.** ADR-B D-4 required `check_revoked=True` and D-6 listed an
`auth/revoked-token` error code. Neither exists. `check_revoked` is a keyword
argument of `firebase_admin.auth.verify_id_token`, and `firebase-admin` is in
neither `backend/pyproject.toml` nor `backend/uv.lock`. What shipped instead is
a provider-agnostic verifier — `OidcTokenVerifier` is a single `jwt.decode`
against a JWKS, asserting signature, `iss`, `aud`, `exp`, `iat` and `sub` and
nothing more. Generalising the verifier is what dropped the one Firebase-
specific assertion, because revocation is not an OIDC concept.

**What changed.** D-4 is struck and superseded by D-11 (what verification
actually asserts — six things, with issuer and audience as configuration rather
than the hard-coded literals D-4 named) and D-12 (there is no revocation check;
revocation latency equals the token's remaining lifetime). D-6's
`auth/revoked-token` is struck in place. `backend/docs/SECURITY.md` gains a
**Known gaps** section, `ACCESS_CONTROL.md` §3 gains the cross-reference, and
the stale row in `docs/specs/GGU-3/api-contract.md` §6 is struck.

**Next person should know**

- **The comfortable version of this gap is wrong, and it is the version everyone
  reaches for.** "A revoked token reads as `auth/invalid-token`, so the client
  signs out" is false. Revoking a Firebase session invalidates the *refresh*
  token and sets a valid-since watermark; the ID token already issued keeps its
  valid signature, `iss`, `aud` and `exp`, and nothing in `auth/claims.py` reads
  a watermark. For the rest of that hour the request is **accepted with a 200**.
  What signs the user out is D-7 — at expiry the refresh fails at Firebase. The
  client is correct; the mechanism is expiry, not rejection. Check the mechanism
  before calling a gap harmless.
- **A control mapping that overstates is the defect.** The SECURITY.md matrix
  never claimed revocation in a row — that part was clean. The overstatement was
  a *threat note* saying "`check_revoked` semantics belong to the provider
  adapter", which reads as a control assigned to a layer, and no adapter has it.
  Prose beside a control matrix is read as part of the mapping. Audit it too.
- **Two records can be individually right and jointly wrong.** `ACCESS_CONTROL.md`
  §3 has said "revoke at the IdP — takes effect at the next token expiry (≤ 1 h)"
  all along, which is exactly correct and flatly contradicts ADR-B D-4. Nobody
  read both. This is the same failure shape as `infra.shell-lint` in
  `ci-conventions.md` §5, and the same fix: when you write a claim, grep for the
  other places that claim lives.
- **Copy the supersession convention, do not invent a second one.** The shape is
  PR #43's (ADR-F D-4): strike the ruling with `~~…~~`, keep it, add
  `superseded YYYY-MM-DD by D-n`, renumber forward, and put the reasoning in a
  dated amendment section. Citations by number must keep resolving.
- **AC-4 went to the other PR's branch, not to `develop`.** `specs/client/0003`
  exists only on PR #48, so §4.4 and OD-3 were fixed in a separate one-file PR
  **based on #48's branch** (#56), not folded into this one — a reviewer of #48
  should see that change on its own. It was **not** pushed onto
  `docs/GGU-82_client_contract` directly: that branch is checked out in another
  agent's live worktree, and `git worktree list` is the cheap way to find that
  out before racing someone. Sequence: #48 → #56, and #43 → #55.
- **§4.4 carried the same comfortable fiction, and was the worse place for it.**
  An ADR states a decision; a client contract tells a developer what to branch
  on. "The backend rejects a revoked token" and "a timer bounds it" prescribe
  different client behaviour — the first invites polling for a rejection that
  never arrives. Fixed there too.
- **Swept `docs/specs/**` for other stale copies** (it predates the current
  specs and was written against the deleted sample). Only one live claim — the
  struck `check_revoked` row in `GGU-3/api-contract.md` §6. Two other hits are
  prose *about* the problem, not claims of a control: `GGU-3` §6's opening
  sentence and `GGU-6/refinement-report.md:155` both say the client "cannot
  distinguish expired from revoked", which is still true. Left alone.
- **Run a new repo-wide gate with its own config before trusting its verdict.**
  Against PR #54's `repo.spelling`, a bare `codespell` from the root reports
  five findings that are all false — `bloc`, `pres`, `re-use` and the untracked
  `backend/reports/`. None survive #54's `.codespellrc`, which lists each with
  the reason it is an exception. Run the check the way the gate runs it
  (`--config` the real file), or the noise buries the one real hit.

---

## 2026-09-20 (cont.) — GGU-78: what a surface is allowed to send back (spec only)

**Spec:** `specs/backend/0022-surface-actions.md` — Draft, awaiting TL approval.
No code. The SDD rule is that a human approves the spec before implementation,
and this one carries a product decision rather than a mechanical one.

**The question.** GGU-15's round-trip has a backend half nobody had designed:
what a generated surface may send *back*. Two interactions do not fit the
options mechanism — a waterfall tap that should make the agent recompose deeper
(GGU-31) and a chip that should start a turn (GGU-32).

**What the spec decides.**

| Question | Answer |
|---|---|
| Is a new mechanism needed at all? | Only for those two. Everything else in the six-component catalog is an option change and needs nothing. |
| The shape | a registered action **id** plus scalar args bounded by the action's own pydantic model. The client never sends prose, a template, a field path, a tool name or a view id; the turn's prompt is a constant in backend code with validated arguments substituted in. |
| Where it goes | **back into the A2A turn**, as an A2A `data` part — not a REST resource. Every action's observable result is a stream of surfaces, and `/v1` would add a second round trip and a third error shape for the client to parse. |
| Audit | declared per action (`audited`), off for both shipped actions; the seam is tested now so the first deciding action inherits a trail instead of an omission. |
| Idempotency | none, deliberately — nothing in scope mutates. The registry **refuses** `mutating=True` outright, so the first mutating action cannot be added without amending the spec. |

**The line worth keeping.** *If the answer is the same view with different
numbers, it is an option. If the answer is a new agent turn, it is an action.*
The failure this spec exists to prevent is a second, looser copy of the options
mechanism — the design ADR-K D-3 already argues against, arriving through the
front door because no bounded alternative was offered.

**Next person should know**

- **Approving this spec obliges an ADR change.** ADR-J D-6 requires a recorded
  decision to extend the JSON-RPC surface, so the implementing PR must add
  ADR-J D-7 (or a short ADR-L). Written as OD-6 so it cannot be missed.
- **A cheaper answer exists and is on the table.** OD-7: if GGU-31 is scoped to
  "the same chart, focused", a bounded `focus` option does it and this spec is
  unnecessary — a chip is then plain `text` and GGU-32 needs nothing either.
  Recorded so that choice is made on purpose rather than by momentum.
- **`RenderIntentService` has no call site on the agent turn path.** It is what
  enforces ADR-K D-11/D-12, its docstring names GGU-47, and nothing calls it —
  so render intents from tools are only pattern-checked today. Found while
  mapping this ticket; it needs its own ticket before `surface.actions` is
  switched on.

---

## 2026-09-20 — GGU-84: the render-intent enforcement finally has a call site

**Spec:** `specs/backend/0005-presentation-layer.md` (AC-9), `specs/backend/0006-agent-host.md` (OD-2, now closed).

**Code.** `RenderIntentService` — the class that enforces ADR-K D-11/D-12 —
was called by nothing. Not by a controller, not by the turn: its provider
`get_render_intent_service` was constructed and handed to nobody, and the only
test touching the wiring asserted the factory returned something. What
actually guarded a tool-emitted view id was `VIEW_PATTERN`, a regex on the
string's shape that `totally.invented.v9` satisfies, and **options were never
validated on that path at all**.

- `RenderIntentService.accept(view=…, options=…, default=…)` is the verdict
  without the payload (registry + options model + `REJECTED_METRIC` + fallback);
  `render` is now `accept` followed by the render, so there is one verdict.
- `services/agent_renders.TurnRenderResolver` translates between the agent's
  `RenderIntent` and that verdict; `AgentService` takes it as one more
  collaborator and `services/agent_tools.execute_tool` calls it at the single
  point an intent enters a turn — which covers both ways one leaves (the
  streamed `SurfaceReady` and the final `TurnResult`).
- `VIEW_PATTERN` → `VIEW_ID_SHAPE`, with the comment saying what it is: a bound
  on the string, never the check.

**Harness.** `tests/unit/api/test_deps_are_wired.py` asserts the *class* of
defect away: every `get_*` that `app.api.deps` exports must be reachable from
a route of the real app, following both FastAPI's dependency graph and the
provider-calls-provider edges read out of the package's own source. Its second
test deletes the `get_agent_service` → `get_render_intent_service` edge and
requires the guard to go red, because a reachability check that passes
everything is worse than none.

**Next person should know**

- **A `Depends` provider looks wired by virtue of existing.** That is the whole
  illusion: it type-checks, it has a unit test, it is re-exported in `__all__`,
  and no request ever resolves it. Nine defects of this class in one iteration;
  this is the first one where the missing line was *never written* rather than
  deleted, so no diff could have shown it.
- **Assert at the seam, over the registry.** The new suite drives a
  tool-emitted intent through a real turn, parametrised over every registered
  projection — so a chart whose options model a turn cannot satisfy fails in
  CI rather than in a conversation. On the way it proved the sweep can be
  vacuous: run alone, the file collected **zero** projections, because
  importing `app.presentation.views` is what fills `REGISTRY`. A sweep needs a
  test that the sweep found something.
- **A rejection must answer, not fail.** ADR-K D-12 is the easy half to get
  wrong: it would have been simpler to raise. The fallback is what keeps a
  model's bad guess from ending a conversation, and it is asserted at the HTTP
  surface, not only on the class.
- **`docs/diagrams/05-agent-turn.md` had been merged twice into itself** —
  duplicated participants, two contradictory claims about who validates an
  intent (`H-->>P` said the turn, another line said the client). Rewritten as
  one diagram. Worth a look at the others.
- **What could not run here:** Docker (host disk full), so the integration
  suite and the compose stack did not run and coverage reads 97.56 % with the
  DB suite deselected — every file this PR touches is at 100 %. The manual run
  in the PR drives the real A2A route in process with the in-memory portfolio
  provider instead; CI has the real verdict.

---

- **An instruction loses to the example beside it.** The reviewer-account
  runbook said *never inline* and then showed `export DEMO_PASSWORD='…'`
  directly underneath. Three passwords reached a session transcript in one
  afternoon, each one pasted from that example by someone following the
  document. The words were right and nobody read them, because the block below
  was runnable and the sentence above was not. `read -rs` does not echo, so the
  same session can be pasted into a chat or a ticket without disclosing
  anything — the fix is a mechanism, not a stronger warning. When a document
  tells someone what not to do, check that the copyable part agrees.

---

## 2026-09-20 (cont.) — the client joins the stack, and a manifest that could not build itself (GGU-82)

**Specs:** `specs/client/0002-client-delivery.md`

**Code.** `client_flutter/` gained a container: multi-stage, both stages pinned
by digest, non-root (uid 101), read-only root filesystem, `no-new-privileges`,
`/health` (not `/healthz` — the harness log above explains why), and a static
nginx that serves the bundle with its own CSP. `docker-compose.yml` gained a
`client` service behind a `client` profile, so a backend-only `docker compose
up` still does not pay for a Flutter build. `client_flutter/docs/SECURITY.md`
is the client's control mapping; it has fourteen implemented rows and **ten**
listed gaps.

**Two decisions worth carrying forward**

- **`BACKEND_BASE_URL` is read at run time, not compiled in.** The argument
  that nearly won — "a baked-in value is shipped to every browser" — is wrong,
  and writing it down as the reason would have been worse than picking the
  other option: the backend URL is public either way, it is in the network tab
  on the first call. The reason that survives is **artifact identity**.
  `backend-cd.yaml` promotes one digest through probe-then-shift; a
  per-environment client image would mean the artifact CI verified is not the
  artifact that ships. So the entrypoint renders `/config.json` at start.
- **`wasm-unsafe-eval`, never `unsafe-eval`.** CanvasKit is WebAssembly, so
  `script-src` must permit instantiation — but the narrow directive does only
  that. `flutter build web --csp` is what keeps the broad one unnecessary, so
  **the flag and the header are a pair**; whoever removes `--csp` has to widen
  the header, and should have to notice. `style-src 'unsafe-inline'` remains
  and is written down as residual risk rather than quietly dropped.

**Next person should know**

- **Building the thing is how you find out the manifest is fiction.**
  `client_flutter/pubspec.yaml` declares `flutter: ">=3.35.7"` / `sdk:
  ">=3.10.0"`. Its own checked-in `pubspec.lock` resolves against `flutter:
  ">=3.44.0"` / `dart: ">=3.12.0"`. Installing the declared minimum fails
  version solving outright. Nothing had ever installed it — every developer had
  a newer SDK already on their machine, and there is no client CI — so the
  declared floor had been decorative since the day it was written. Same shape
  as the seven claims in the entry above: believed, never executed.
- **An `add_header` inside an nginx `location` replaces every inherited one.**
  A per-location `Cache-Control` would have silently deleted the CSP from the
  HTML response — the one response that needs it. The config uses a `map` and a
  single server-level `add_header` for exactly this reason. If someone adds a
  header to a `location` later, they have to re-add all of them.
- **`envsubst` needs its variable list.** `envsubst < in > out` with no
  SHELL-FORMAT argument expands nginx's own `$uri`, `$host` and
  `$request_method` to empty strings, and the resulting config still starts.
  The entrypoint passes `'${PORT} ${CONNECT_SRC}'`.
- **The evidence for this PR is incomplete, and that is stated in the PR rather
  than papered over.** The host ran out of disk (460 GiB volume at 100 %, 2 GiB
  free) mid-run and took the Docker daemon down with it, so the image was never
  built end to end and the `docker run` / `curl -I` proofs AC-5 asks for are not
  in the PR body. What *is* pasted is real: the version-solving failure above,
  and the compose profile check. Do not merge on the strength of the rest —
  the container's claims are unverified until someone runs it.
- **Ten gaps, and the first one is the interesting one.** The client's login
  (`login_bloc.dart`) is a fake that emits `success` for any input after a
  two-second delay. There is no token anywhere in the browser, so every control
  about token storage would have been invention. The mapping says so instead.

---

## 2026-09-20 — GGU-82 follow-up: the container was actually built and run

**Spec:** `specs/client/0002-client-delivery.md` · **PR:** #49 (same branch)

**What changed in code**

- `client_flutter/Dockerfile` — the builder stage no longer uses a community
  Flutter image. It is `debian:12-slim` by digest plus Google's own SDK archive
  verified against the SHA-256 in `releases_linux.json`, and `flutter pub get`
  gained `--enforce-lockfile`.
- `client_flutter/docs/SECURITY.md`, `specs/client/0002-*.md` — every ⧗ that
  was watched became a ✓ with the observation in the cell; one ⧗ stayed; gaps
  G-6, G-8, G-11, G-12 rewritten and G-13 added.

**Next person should know**

- **The lockfile's `sdks:` range does not name the SDK that wrote it.** The
  previous entry said the declared floor `flutter: ">=3.35.7"` was fiction and
  that `pubspec.lock` wanted `>=3.44.0`. Both true, and still not enough:
  **3.44.9 cannot reproduce the lock either.** The SDK *vendors* some of what
  the lock pins — 3.44 pins `meta 1.18.0` and `vector_math 2.2.0` exactly,
  while the lock holds `1.19.0` / `2.4.2`, which only 3.47.x admits. The floor
  in the lock is derived from package constraints; it is not a record of the
  toolchain. `--enforce-lockfile` is the only thing that says so out loud —
  plain `pub get` would have re-resolved 14 dependencies and built something
  nobody reviewed. Keep the flag.
- **A CSP can be correct in a header grep and still break the app.** This is
  the check worth adding to `client-ci.yaml`: the page loaded with the console
  read. Served under `script-src 'self'` this bundle is a *blank page* — 200 OK,
  every header present, nothing rendered. `curl -I` cannot see that.
- **Reasoning got OD-3 right and one detail of G-6 wrong.** `wasm-unsafe-eval`
  is necessary and sufficient, as argued. But G-6 said Flutter's injected
  styles have "no supported nonce or hash path", and the browser's violation
  report does offer per-element hashes. The accurate claim is narrower: Flutter
  has no supported way to emit them. Worth noting because the reasoning was
  90 % right, which is the kind that survives review unexamined.
- **`docker run --rm <img> id` does not print a uid here**, and the first draft
  of the PR told reviewers to run exactly that. The entrypoint requires
  `BACKEND_BASE_URL` and exits 1 before any CMD argument matters, so the
  command "fails" for a reason unrelated to what it was asking. Use
  `--entrypoint id`. A verification command nobody has run is worth about as
  much as a control nobody has tested.
- **ghcr.io is refused by this machine's Docker registry policy.**
  `ghcr.io/cirruslabs/flutter:3.44.0` exists, has a native `linux/arm64`
  manifest and would have fitted; every pull answers `denied` while Docker Hub
  works. Anything that needs ghcr has to be resolved with whoever owns that
  policy, not worked around.
- **G-11 is closed, and the way it closed is reusable.** The hardening was
  first proven with `docker run` and the flags compose declares, which is not
  the same claim — it leaves a typo in `docker-compose.yml` undetected. Compose
  will not parse this project without `backend/.env`. The way through is a
  throwaway overlay that resets only the *backend* service's env_file:

  ```yaml
  services:
    backend:
      env_file: !reset null
  ```

  `docker compose -f docker-compose.yml -f overlay.yml --profile client up -d
  --no-deps client` then works with no credential anywhere, and the `client`
  service stays exactly as committed. `docker inspect` on the container compose
  created reports `Config.User=101`, `ReadonlyRootfs=true`,
  `SecurityOpt=[no-new-privileges:true]`, `Tmpfs=map[/tmp:]` and
  `Up (healthy)` — declared and applied agree. **`client-ci.yaml` should use
  this overlay rather than putting a real `.env` on a runner**, and that is now
  written into spec 0002 §9.
- **The obvious way to unblock compose was to borrow the developer's real
  `backend/.env`. Don't.** It holds a live `GEMINI_API_KEY`, the harness denies
  `**/.env` precisely so an agent cannot reach it, and a key that reaches a
  transcript is a key that has to be rotated. The overlay above gets the same
  proof and touches nothing secret. If a future task looks like it needs that
  file, it almost certainly needs an overlay instead.

---

- **A check with two configurations drifts like a check with two command
  strings.** `make gate` ran codespell over `backend/` only while pre-commit
  ran it over everything, so a typo in `specs/` passed a green gate — measured
  both ways: the new root check exits 65 on it, the old scope exits 0. The
  second half was subtler. The hook read `backend/pyproject.toml`, whose word
  list knows nothing about Flutter, so it flagged `bloc` three times on a
  single `login_bloc.dart` and failed every commit that touched one. A hook
  that fails on correct code teaches people to bypass it — and a bypassed hook
  is how the `specs/` typo reached `develop` in the first place. The scope gap
  and the false positives were the same defect seen from two ends.

---

## 2026-09-20 (cont.) — GGU-91: a second Flutter app, and its whole harness (#TBD)

---

## 2026-09-20 (cont.) — GGU-91: a second Flutter app, and its whole harness (#58)

**Spec:** `specs/frontend/0001-frontend-skeleton.md` · **ADR:** ADR-L (Proposed)

**Code.** A new top-level `frontend/`: a pub workspace with one lockfile and
four packages — `finance_core`, `finance_api_client`,
`finance_views_repository` (all pure Dart) and `app` (Flutter). One composition
root, `go_router`, Material 3 with a spacing `ThemeExtension`, sealed
`Result`/`AppFailure`, and one vertical slice: `holdings.allocation.v1`
fetched, decoded and rendered. 159 tests, 100 % line coverage on 26 files.

**Harness.** All eight pieces, mirroring the backend's: `frontend/CLAUDE.md`;
three project rules under `.claude/rules/frontend/` with `paths:` frontmatter;
a `post-edit-dart.py` PostToolUse hook registered beside the Python one; a
read-only `frontend-reviewer` agent; the ship-gate triple
(`frontend.*` in `ship-gate.json` ≡ `frontend/Makefile gate` ≡
`frontend-ci.yaml`, command strings copied); the spec; this entry; and the
`docs/DEV_HARNESS.md` section. Plus diagram `12-frontend-layers.md`, the
pre-commit hooks, and `ci-conventions.md` §5's table gaining a `frontend.*`
row.

**The point of the whole thing, in one sentence:** the backend half of this
repository enforces its standards with tests and a gate while the client half
enforced nothing, so every rule here is held by a script that was
**mutation-checked** — a forbidden import, a `NumberFormat`, a 151-line file
and an unregistered component directory each turned the suite red before being
reverted.

**Four defects the gate found in its own PR**, which is the argument for
building it first:

| Found by | What was wrong |
|---|---|
| a repository test | `ViewPayload` had no value equality, so two identical envelopes compared unequal — bloc state would have re-emitted on every fetch and `bloc_test` expectations would have been identity-based |
| `check_file_budget.dart` | three test files over 150 lines; splitting them produced the two shared harnesses the suites now use |
| `check_coverage.dart` | a `props` override on a sealed base that no subclass used (deleted), and a credential closure that could only be reached through a live request (extracted to `devTokenProvider`, now testable) |
| `dart analyze --fatal-infos` | 21 findings in test files alone, none visible while only `lib/` was being analysed |
| **CI's `build` job** | the app had **no `web/` scaffold at all** — it was assembled by hand rather than by `flutter create`, so a web-first client could not build for web. Every local check was green. |

**Next person should know**

- **`flutter pub get` silently re-resolves; `--enforce-lockfile` does not.** Every install and every CI job uses the strict flag. A build that resolved differently from the reviewed one is the whole failure mode.
- **`dart fix --apply` is not safe to run blind on Dart 3.13.** It rewrote every constructor into the new `const new(…)` shorthand and injected a *circular self-import* into two barrel files to satisfy `comment_references`. Both changes were "valid" and both were worse. The two lints are now off in `frontend/analysis_options.yaml` with reasons (ADR-L D-10). Read a `dart fix` diff.
- **Dart's lcov has no branch data.** "100 % branch coverage" is not expressible for Dart, so this half holds 100 % **line** coverage *per file* instead. That is why the two halves of this repository state their coverage contracts differently, and it is recorded rather than quietly rounded to 80 %.
- **Reaching 100 % three times meant deleting or extracting code, not writing a contrived test.** That is the coverage gate doing design review.
- **A widget test through a bare `MaterialApp` hides wiring bugs.** `pumpApp` uses the real theme and the real providers; the `AppSpacing` equality defect surfaced only because a test compared a `ThemeExtension` read back out of a real `ThemeData`.
- **Dart has no runtime reflection on the web**, so an unimported library is tree-shaken and its registration never runs. "Adding a component edits no existing file" is therefore only true because the one file that imports them is **generated and diffed by the gate** — the same shape as the backend's frozen catalog.
- **`go_router`'s configuration is empty until it is attached to a widget tree.** Asserting on `currentConfiguration` from a bare `buildRouter()` fails with `Bad state: No element`; route tests have to pump.
- **A hand-assembled Flutter package has no platform scaffold, and nothing local tells you.** `make gate` was green, 159 tests passed, and `flutter build web` said *"This project is not configured for the web."* The gate's local half cannot prove a bundle compiles; that is why `frontend-ci.yaml` has a `build` job, and it earned its place on the first run. `flutter create . --platforms web` also drops in an `analysis_options.yaml`, a `README.md`, a `.gitignore` and a default `widget_test.dart` — the first of those would have silently shadowed the workspace analyzer configuration. Delete all four; keep `.metadata`.
- **The review round found four things the gate asserted and did not hold.** Recorded because the shape repeats — a property written down, enforced by nothing — and it is the same shape as every defect in the entry above.

  | Claimed | What was true |
  |---|---|
  | "errors shown to a user are the backend's safe text" | the transport passed `http.ClientException.message` straight through — package:http's own wording, and on `BrowserClient` it carries the target URL. A comment two lines from the render site asserted the opposite. The cited test only ever built a `ProblemFailure`, so it **could not** fail for the half that was wrong. |
  | "no client-side interpretation of server strings, verified by the layering test" | that file had no such rule. The property was true by construction; the citation was a gap dressed as a control. |
  | `*.iml` is gitignored | `.gitignore` has no inline comments — `#` only opens one at column 0 — so the pattern was the literal string `*.iml  # IntelliJ…` and matched nothing. `git check-ignore` exits 1 and says so. |
  | "100 % line coverage per file" | really "100 % of the files the tests happened to load". lcov writes **no record** for a library nothing imports, so a new untested file passed silently. 30 files on disk, 26 records. |

  The last is the one to carry forward: **a coverage gate that iterates the report can only ever see what the report contains.** `check_coverage.dart` now takes the file list from disk and fails on a missing record, deciding "no executable code" by parsing rather than by a hardcoded barrel list. An untested `lib/` file turns it red — mutation-checked.

- **A filename rule cannot separate two classes that share a file.** The first attempt at "only a `*_page.dart` may read a repository" passed its own mutation check *green*, because `PortfolioViewsView` lived inside `portfolio_views_page.dart`. The fix was to split the file, which the page/view split wanted anyway. The mutation caught it; reading it twice had not.
- **Needle lists have holes on the `try` prefix.** `double.parse` does **not** match `double.tryParse` as a substring, and `tryParse` is the form a developer reaches for first. Both spellings of `double`, `num` and `int` are now listed, plus `DateTime.timestamp()` beside `DateTime.now()`.
- **The frontend gate cannot be run without a Flutter SDK, and this machine had none.** It was verified against a pinned 3.47.5 downloaded for the session. Anyone reproducing it needs that SDK, not merely Dart — `dart test` covers the three pure packages but not the widget suite.

---

## 2026-09-20 (merge) — GGU-91 merged with the manual run **waived**, not satisfied

**Recorded because a waived gate and a passed gate are different things.**

`.claude/rules/backend/sdd.md` requires every PR body to carry *"a manual run
against the running stack with the real commands and their real responses
pasted in. No manual run, no merge."* PR #58 does **not** carry one, and says so
in its own body: `backend/.env` does not exist in a worktree and creating it is
denied by this repository's own permissions (`Edit(**/.env)`), so
`docker compose up` could not start the API. The author did not route around the
deny — the correct call.

**The TL waived the requirement for this PR and authorised the merge.** The
blocker paragraph is left standing in the PR body on purpose: it is the record
of what was not done. Nothing here says the manual run passed, because nobody
ran it.

**What that leaves open.** The frontend gate (`cd frontend && make gate`) and
`frontend-ci.yaml` both ran green, so the code is proven against its tests and a
real web build. What is *not* proven is the thing only a running stack shows:
that the client actually reaches this backend — `BACKEND_BASE_URL`, CORS, the
bearer token, and the shape of a real `?view=` response against a real
projection. Spec `frontend/0001` still owns that.

**Next person should know**

- **The first task for whoever has a `.env` is to do the run this waiver skipped**,
  and to append the result here. Until then, treat "the frontend binds the
  backend" as asserted by tests, not observed.
- **A permission deny is not a reason to lower a gate.** The gate stayed where it
  was, the PR said plainly what it could not do, and a human took the decision.
  That is the shape to copy the next time the sandbox blocks a verification.

---

## 2026-09-20 (cont.) — GGU-90 + GGU-88: the turn that actually completes · spec `specs/backend/0006-agent-host.md`

**What changed in code.** Two defects in `infra/model/payload.py`, fixed
together because either one alone still leaves the turn at a 400 on the
*second* model call:

| Defect | Fix |
|---|---|
| `MessageRole.TOOL` → role `"function"`, which Gemini refuses outright (GGU-90) | → `"user"`. Gemini has **no tool role**; the `functionResponse` *part* is what marks a tool result. Accepted roles measured in the new `infra/model/wire_roles.py` |
| `from_response` dropped Gemini 3's `thoughtSignature`, and the next request is refused without it (GGU-88) | it round-trips as `ToolCall.provider_state`, an opaque bag the adapter fills and empties |

`payload.py` was split: request mapping stays, response mapping moves to the
new `reply.py` (both were at the 150-line cap). `gemini_client.py` handed its
retry triage to the new `provider_errors.py`, which also carries GGU-90 AC-4.

**The masking was half a contract.** The adapter masked every provider failure
as `dependency-unavailable` — correct at the API boundary — and then threw the
text away, so two 400s that broke *every* agent turn looked like an unavailable
provider and cost an hour each to find by replaying the call by hand. Masking
outward and recording inward are different decisions; we had only the first.
`log_provider_failure` now writes the provider's own bounded diagnostic to the
server log at `warning`. Nothing the caller sees changed, and there is a test
asserting both halves at once.

**What changed in the harness.** Nothing in `.claude/rules/**`. The diagram
`docs/diagrams/05-agent-turn.md` gained the two provider facts that make the
"tool results fed back" edge work; spec 0006 gained OD-13, the two new modules
in its file table, and an honest amendment to AC-13 (a second log line now
exists, on the failure path only).

**Next person should know**

- **A test that compares our constant to a copy of our constant is not a test.**
  `test_payload.py` asserted a tool result went out under role `"function"`,
  and it did, and it passed for as long as the code was broken — the assertion
  was the mapping, written from the same belief on the same day. `wire_roles.py`
  holds an answer the *provider* gave, quoted from its own refusal, and
  `test_wire_roles.py` walks `MessageRole` so the next role is checked the day
  it is added. Same shape as `tool_schema_keys.py` (GGU-81). This is the
  thirteenth instance of this pattern in this iteration.
- **Defects on one code path stack, and only the outermost is visible.** GGU-81
  hid GGU-90, which hid GGU-88. Each was "the" reason turns failed. Fixing one
  and declaring the path healthy would have been wrong three times; the only
  honest check was driving a real turn after each fix.
- **A/B against the live provider beats any amount of reading.** The same
  question, same key, same stack, two images minutes apart: pre-fix ends at
  `status-update(failed)` + `dependency-unavailable`; post-fix reaches the
  terminal `message`. That contrast is the whole evidence, and it is cheap.
- **The integration suite is not idempotent against a reused database** and
  nothing fails when it is not — 1214 tests stay green and only `fail_under`
  notices, because `portfolio_repository.py`'s lost-race branch needs an empty
  table. Fresh volume: 100 %. Second run: 99.96 %. The integration tests use
  fixed literal subjects (`subject-restart`, `subject-once`, …) against this
  repo's own rule that test data is unique per test. CI always starts clean, so
  it is permanently green there. **Not fixed here — it is not this ticket's
  code.** Flagged for a ticket of its own.

---

## 2026-09-20 (cont.) — GGU-78: surface actions, and a catalog that was under-reporting

**Spec:** `specs/backend/0022-surface-actions.md` (Draft → Implemented; the file
arrives from PR #44, which is spec-only — expect a whole-file conflict there).
**ADR:** ADR-J gains **D-7**, the decision D-6 requires before the JSON-RPC
surface may be extended.

**What changed in code**

- `app/actions/` — a framework-free peer of `presentation/`: contract, spec,
  registry, resolver, the `SurfaceActionRef` a payload publishes, the curated
  suggestion table, and one module per action under `defined/`. Adding an
  action edits no shared file, the way adding a chart does not.
- The A2A envelope accepts one `data` part carrying `{action, args}` — bounded
  to eight scalar arguments, no nesting, no arrays — resolved **before** the
  stream opens, so a refusal is a JSON-RPC error rather than a stream that
  fails on its first event. Flag `surface.actions`, dark-launched **off**.
- `attribution.waterfall.v1` declares `drill.attribution.v1`; the declaration
  reaches the payload, the A2UI props, `GET /v1/views` and `CONTRACT.md` from
  one derivation.
- `order.ticket.v1` now names `size` and `size_in` as payload fields.

**The defect worth remembering**

`order.ticket.v1` offered four editable controls and the generated contract
reported **two**. Nothing was wrong with either declaration on its own:
`inputs[]` published all four, and the document's rule — *an editable field is
a payload field named exactly as the option that sets it* (spec 0019 OD-3) —
was applied correctly. They simply disagreed, because `symbol` and `side`
happened to share a name with a payload field and `size`/`size_in` did not.
**Nothing compared the two declarations**, so the document quietly advertised
half of what the component accepts, and a client binding to it could not know
`size` was editable.

The rename is not the deliverable; `test_declared_interactivity.py` is. It
walks the **registry**, so the next component to get this wrong fails the gate
instead of shipping, and the failure names the projection and both sides of
the disagreement rather than printing a bare set mismatch.

**Next person should know**

- **A third declaration of one fact is a third place to drift.** This package
  now has two derived ones — `TicketInput` from the options schema,
  `SurfaceActionRef` from the arguments schema — and both are derived
  precisely so they cannot be retyped. Keep deriving.
- **A derived figure is never an input.** `quantity` was the obvious thing to
  rename to `size`, and it would have been wrong: under `size_in="usd"` it is
  the size *divided by the entry price*, so the contract would have advertised
  as editable a value the options model refuses.
- **An error message is an output with a bound.** Argument names are capped at
  32 characters and a rejection names only arguments the action *declares*,
  replacing anything else with `<undeclared>` — because that name came from
  the caller and lands in a 256-character JSON-RPC field. `a2a_dispatch`
  already learned this the expensive way (a 500 from an over-long `repr`).
- **A test that only passes on an empty table is worth less than no test.**
  The first draft of `tests/integration/test_a2a_actions_flow.py` asserted the
  flag was off *before* any test turned it on: green on a virgin database,
  red on the second run of the same file. Every test there now sets the state
  it needs and puts it back, and "off by default" is asserted in the unit
  suite, where it is a property of the call rather than of a stored row.
- **`docs/diagrams/05-agent-turn.md` was a corrupted double-paste** — two
  merged versions, duplicate `participant` lines, an undeclared `DB`. It would
  not have rendered. Repaired while adding the action path to it; worth a look
  at whether other diagrams carry the same scar.
- **Pre-existing and not fixed here:** `test_list_recent_and_list_for_subject_
  order_newest_first` is order-dependent — three audit rows written in one
  transaction share a timestamp, so "newest first" is a tie the database
  breaks arbitrarily. Filed as its own task; the ordering guarantee belongs in
  the repository, not in the test.

### Review round on #57 — two findings that were both right

**A vacuous test that claimed the opposite.** `test_declared_interactivity.py`
was written to walk the registry, and the PR body said its third case "covers
the projections with no `inputs[]` too". The reviewer enumerated the registry
and found that for **four of six** projections all three cases executed *zero*
assertions: case 1 subtracted from an empty set, case 2 skipped, and case 3
looped over an empty list. Worse, the vacuous set contained
`attribution.waterfall.v1` — the projection the PR changes.

The fix was to stop asserting over a *derived set* and start asserting the
**rendered claim**: `read-only` is itself a claim that can be wrong, so
checking it gives a read-only projection a real assertion. Proven by mutating
`inputs_note` to never return `READ_ONLY`, which now turns exactly those four
projections red. A vacuity guard (`test_the_registry_still_produces_both_kinds_of_case`)
pins that at least one projection of each kind exists, so the file cannot
quietly go empty again.

The lesson is narrower than "write better tests": **a parametrised test over a
registry reports as N passing cases whether or not its body ran.** Green
parametrised output is not evidence of coverage; count the assertions.

**A contract that shipped on while the capability shipped off.** The waterfall
declared `drill.attribution.v1` unconditionally while `surface.actions` ships
off, so `CONTRACT.md`, `/v1/views`, the payload and the A2UI props all
advertised an affordance that answers `-32601`. "Dark-launched" was true of
execution and false of the contract.

Both now read one constant, `app.actions.capability.SHIPPED_ENABLED`. The
skew is one-directional on purpose: enabling the flag at runtime without
flipping the constant means the capability works and nothing advertises it,
which is safe; advertising more than the service will do is the defect. A
footnote was the alternative and was rejected — #45/#48 ship that catalogue to
the client as a **machine-readable** artefact, and a footnote in Markdown does
not reach a JSON consumer.

**Next person should know**

- **Gating a declaration cascades into the tests that prove the declaration.**
  Three tests went vacuous the moment nothing declared an action, and had to
  be re-pointed at a projection registered inside the suite. If you flip
  `SHIPPED_ENABLED`, expect the reverse cascade and check the probes still
  earn their place.
- **`vulture` will not find an unused module-level constant.** `NO_ACTIONS`
  was defined identically in two modules, and coverage stayed at 100 % because
  the assignment *executes*. `min_confidence = 80`; an unused module-level
  assignment scores 60.
- **`except AppError` at a protocol boundary is too wide.** In `a2a_actions`
  it would have mapped a `DependencyUnavailableError` from an audited action's
  audit write onto `-32602` *and put its detail on the wire*. Narrowed to the
  three refusals that are genuinely the caller's fault.

---

- **A gate can be red for the wrong reason and blind to the right one.** The
  repository-wide spelling check shipped as a bare `codespell`, whose directory
  walk skips dot-entries — so `.claude/` and `.github/` were never scanned,
  while the check's own comment and `ship-gate.json`'s note both said they
  were. a misspelling of `unparsable` sat in this very file with the gate green. Planting a
  typo in `.claude/` gave **exit 65 and zero hits on the planted file**: red,
  from `uv.lock` and `backend/reports/`, and entirely blind to the mutation.
  Anyone confirming the gate "works" by watching it go red would have been
  satisfied. It now scans an explicit `git ls-files` list and asserts that
  `.claude/` and `.github/` are in it. Found by the agent merging the session's
  pull requests, in a gate I had written and mutation-checked the same day —
  my mutation proved a typo in `specs/` was caught, and I generalised from one
  directory to "the repository" without testing the generalisation.

---

## 2026-09-21 — the gates cover the pull requests this repository actually opens

Remediation of the 2026-09-20 Security Audit (87/100, down from 98). No spec:
this is CI topology and documentation correction, not a feature. Branch
`ci/security_gates_cover_every_pr`.

**The finding, in one sentence.** Root `SECURITY.md` claimed "gitleaks,
pip-audit, Trivy and Semgrep on every PR (`backend-ci.yaml`)" and
`VULNERABILITY_MANAGEMENT.md` marked Secrets and SAST "Blocking: yes / every
PR", while `backend-ci.yaml` is `paths:`-scoped to `backend/**`. A
frontend-only or client-only pull request started none of it — which by
2026-09-20 was most of them.

**What moved, and the rule it produced.** `repo.secrets` (gitleaks) moved out
of `backend-ci` and `repo.shell-lint` (shellcheck) out of `infra-ci`, both into
`repo-ci.yaml`, which carries no `paths:` filter. `backend-cd` now calls
`repo-ci` as a second gate job so the move did not quietly take secret scanning
off the path to production — `test_dev_environment.sh` asserts that edge and
was mutation-checked against its removal.

The general rule is now in `ci-conventions.md` §4b/§5: **a check whose subject
is "any file in this repository" cannot be correct in a `paths:`-scoped
workflow.** The test is the check's subject, not where it currently lives: if
you cannot name a directory it does *not* apply to, it belongs in `repo-ci`.

**§5 has two questions, and only the first was ever asked.** `infra.shell-lint`
and its workflow step matched byte for byte — §5 satisfied — and the check was
still wrong, because its *subject* was two globs under `infra/scripts/`. Both
container entry points were outside it, and pointing shellcheck at them for the
first time found a finding in each (SC2086 in `backend/docker/entrypoint.sh`,
SC2016 in `client_flutter/docker/entrypoint.sh` — both deliberate constructs
that now carry justified `disable` directives rather than a lowered severity).
So: (1) do both halves run the same command — now machine-checked; (2) does
that command cover what its name claims — still human, and the expensive one.

**The first question is no longer a human's job.** `repo.gate-pairs`
(`scripts/check_gate_pairs.sh`) parses `ship-gate.json` and greps each `cmd` as
a fixed string against every workflow file. Every one of the 23 entries already
satisfied it, so it shipped green and would have caught all three historical
drifts. It is deliberately one-directional and cannot check the "Also in"
column — `gitleaks` and `codespell` are upstream pre-commit hooks with no
command string to compare.

**A rule may not describe a workflow nobody wrote.** §4b's table listed
`client-ci` among the scoped workflows with no marker, and it has never
existed. The table now carries an `exists?` column and says so. It was **not**
written here: `client_flutter/CLAUDE.md` lists
`.github/workflows/client-ci.yaml` under "do not touch" and assigns it to
GGU-1 (PR #30). The security half of that gap is now covered by `repo-ci`
anyway; the image build and its CVE scan are genuinely uncovered and are
recorded as gaps with that owner.

**What the next person should know.**

- Two new repository-wide scripts, `scripts/check_shell.sh` and
  `scripts/check_gate_pairs.sh`. Both discover their subject rather than
  enumerating it, and both refuse to report success on an implausible file
  list — the anti-vacuity idiom `check_spelling.sh` established.
- `check_shell.sh` avoids `case` inside command substitution because **bash
  3.2, which macOS still ships as `/bin/bash`, cannot parse one there** while
  the ubuntu-latest bash 5 in CI parses it happily. The first draft ran green
  on a runner and died on a laptop. Worth remembering for any new script here.
- Do not "fix" the two `shellcheck disable` directives in the entry points.
  `SC2016` is required because `envsubst` takes its variable list as a literal
  `${NAME}` string; `SC2086` is required because `UVICORN_EXTRA_ARGS` must word
  split. Both carry the reason at their own line.
- Dependabot now watches both pub workspaces. That is **update** telemetry, not
  a CVE gate; `osv-scanner` is still a declared gap because its only
  distribution channel is `ghcr.io`, which this project's registry policy
  refuses, so it could not be run even once before shipping. A gate nobody has
  seen go red is not a gate — that is the whole lesson of 2026-09-20, applied
  to the thing it was tempting to skip.

**Postscript, found by this branch's own CI run: `repo.spelling` was red on
`develop`, flakily, for a reason that had nothing to do with spelling.** Its
anti-vacuity assertion is `printf '%s\n' "$files" | grep -q "^.claude/"`.
`grep -q` exits at the first match, `.claude/` sorts first, and `pipefail`
turns the resulting `printf: write error: Broken pipe` into a failed test — so
the script reported *"nothing under .claude/ reached codespell"* about a list
whose **first line** was `.claude/.proven-config-version`. Measured on the real
821-path, 35 KB list on one CPU under load: the pipe form wrongly failed
**18 of 200 runs**, the here-string form **0 of 200**. Under 64 KB it is a
scheduling race, which is why it looked intermittent; past 64 KB printf must
block and it fails every time.

Two lessons, both of which this repository has now paid for twice:

- **An anti-vacuity check is code, and can be wrong in its own right.** This
  one failed *closed*, which is the safe direction and is exactly why it read
  as a genuine finding rather than a bug. "The gate is red" was true; "the gate
  is red about spelling" was not.
- **The idiom spreads.** `check_shell.sh` was written in this same PR and had
  copied the pipeline verbatim; it is latent there only because twelve paths
  fit in a single write. Both are here-strings now. If you add a third
  `check_*.sh`, do not reach for `printf ... | grep -q`.

## 2026-09-21 — GGU-79: the client speaks A2UI, and the seam under it holds

**Spec:** `specs/frontend/0002-a2ui-agent-path.md` · **PR:** #65 ·
**Diagrams:** `12-frontend-layers.md`

`frontend/` had no agent path at all. It now speaks A2A — `message/stream`,
SSE, the four event kinds — and turns each `render-intent` into a surface as
it lands. **No dependency was added**, and the reason is the finding worth
keeping:

- **`genui` / `genui_a2a` / `a2ui_core` are the wrong tool for this backend.**
  They render A2UI component trees. This service sends none: `a2a_events.py`
  emits `{"kind":"render-intent","renderIntent":{"view","options"}}`, and spec
  `client/0003` §8.3 says the intent "names a registered view; it never
  carries a payload. The client fetches the payload itself." The brief for
  this ticket asked for those three packages by name; the wire says they would
  render nothing. Recorded as spec `frontend/0002` OD-1 for TL sign-off.
- **`X-A2A-Extensions` is sent, and the folklore about it is wrong for this
  stack.** Nothing under `backend/src/app/api/` or `services/` reads it. The
  "omit it and A2UI silently degrades" warning describes genui's connector
  against the upstream sample, not this backend (OD-3).

**The seam under it had two holes, and `frontend/CLAUDE.md` claimed it did
not.** "Adding a component edits no existing file" was true of *registration*
and false of everything after it: `app_router.dart` hardcoded a view id with
no test comparing it to the registry, so a component could be registered,
100 %-covered and **invisible with a green gate**; and the fifth component
would have pushed one request past the endpoint's four-id cap. The route now
names no view — the page asks the registry, so the two cannot disagree — and
the repository splits an over-cap request. The claim in `CLAUDE.md` now says
which two things used to break it.

**Two bugs in the gate that guards coverage**, both reproduced before and
after by executing the script against scratch trees:

- an empty source walk printed `coverage ok — 0 lib file(s) accounted for` and
  exited **0** — the disk cross-check reproducing the lcov blindness it was
  written to fix;
- `isExempt` ran against the raw `SF:` path, so the `lib/main.dart` exemption
  never fired on a `flutter test` record, while the message printed the
  **normalised** name, which looks exempt. Latent, not breaking: no test loads
  `main.dart`, so no record exists and the disk side happened to work.

**`SECURITY.md` claimed more than it checked.** All twelve number needles are
*formatting* mechanisms; N-2 ("never compute") and N-10 ("never reorder") were
enforced by nothing. `binding_rules_compute_test.dart` adds nine aggregation
and rounding needles with two written carve-outs, `json.decode(` joins
`jsonDecode(`, and the claim is narrowed — **bare `+ - * /` are named as not
mechanically checked**, because they cannot be needled without matching prose.

### What the next person should know

- **There is no Flutter toolchain on the authoring machine** — and the
  standalone Dart is 3.12.1 against a `^3.13.0` floor, so `frontend/` does not
  even resolve. `make gate` was never run here. `frontend-ci` ran the whole
  gate on every commit of this branch and is the only evidence in the PR body.
  It caught three real defects a local run would have caught in seconds: a
  `library;` directive after an import, an `async_return_with_no_await`, and
  five files the 3.13 formatter disagreed with.
- **The 3.12 formatter is not the 3.13 formatter.** On `binding_rules_test.dart`
  and `result_test.dart` they disagree today (3.13 chains on a multi-line
  receiver; 3.12 splits the argument list). Do not run `dart format .` with an
  older SDK — it will rewrite files CI considers correct. Formatting one file
  at a time and reading the diff is safe when it is a plain collapse.
- **`tool/` still has no tests** and is still excluded from the coverage
  contract it enforces. Adding `package:test` to the workspace root changes
  `pubspec.lock`, which could not be regenerated here. Spec `frontend/0002`
  OD-5 carries it.
- The numbers rule matches **text, not intent**: a comment in
  `conversation_bloc.dart` that merely *named* `DateTime.now(` tripped it. That
  is the rule working, and the comment now says so.
## 2026-09-21 — GGU-53: the catalog serves what the client must draw

Spec: `specs/backend/0023-catalog-serves-the-client.md`. Tickets: GGU-53, and
it touches the promises of GGU-42 (numbers-from-tools), GGU-78 (surface
actions) and GGU-92 (actions in the snapshot).

Design exported four pages of the component catalog. Comparing them against
what this backend serves turned up four disagreements — **three of them
defects here, one a defect in the design**:

1. **Four of six component names were wrong**, not the two the ticket flagged.
   The waterfall and the scenario card disagreed with their own design pages
   too, and nobody noticed because the backend's spelling matched *one* of the
   three names each design page uses. The rule adopted (spec 0023 §3): a
   component is named by its **own A2UI schema block**; a gallery badge is
   decoration, and a mention on another component's page is never
   authoritative.
2. **The payoff curve could not be plotted.** Its y coordinate was an ADR-E
   pair; its x coordinate was a formatted string and nothing else. A client
   would have had to parse `"$142.50"` back into a number — the exact
   client-side arithmetic ADR-K D-5 forbids. `SeriesPoint.at` is the fix.
3. **The waterfall's declared action was unusable.** `drill.attribution.v1`
   accepts a symbol; `Bucket` carried only a prose label (*"Bitcoin"*) and no
   key. The affordance was published, the bound was enforced, and the two had
   no value in common. `Bucket.key` closes it.
4. **The design's schemas type every figure as a bare `number`.** Not
   conceded: ADR-K D-5 already allows the raw figure *beside* the string, so
   the backend ships both.

### What the next person should know

- **`docs/catalog/CONTRACT.md` did not carry the component name at all.** The
  snapshot did, the A2UI surface did, the Markdown did not — so the one
  artefact design actually reads could not be used to check the one string the
  client registers against. It now prints it in the section *and* the index
  table, which is what made a four-way comparison possible.
- **0021 OD-3 is reversed, deliberately, and says so at its own line.** It
  decided against asserting the six component names because an inventory
  transcribed from the registry is a copy of the registry. That is right, and
  it assumed there was nothing outside the backend to compare against. The
  design catalog is that outside thing, so `test_component_names.py` holds the
  list as *the other party to the contract*. The failure OD-3 feared — "it
  breaks when a seventh projection registers" — is now the point: a new
  component must be named by design before it ships.
- **Guidance is `None` for three of six views, on purpose.** Their design
  pages were not exported, so the contract prints *"not guidance this backend
  may invent"* and the prompt omits the lines. Do not fill them in from
  imagination; fill them in from a page.
- **Every digest moved**, because the entry a digest is taken over now carries
  the component and the guidance. `specs/client/0003` §5 and the two Flutter
  fixture headers were updated with it. A moved digest is the mechanism
  working.
- **Guidance prose lives in `<view>_guidance.py`, not in the view.** Three view
  modules are at the 150-line budget, and a designer editing what the model is
  taught should not have to read a projection to find the sentence.
- **`docs/catalog/design/README.md` is the evidence, and it is why the one
  hand-written inventory is allowed.** The exported pages are ~900 KB of
  JS-bundled HTML each and are deliberately *not* committed — that is the
  binary artefact `.claude/rules/diagrams.md` refuses. What they *declare* is:
  each page's four name slots, its Zone 3 text verbatim, and every point where
  design and this backend disagree. A path in `/tmp` would have made
  `DESIGN_CATALOG` unverifiable the next morning.

### Harness

`.claude/rules/backend/presentation.md` gained two things and no hook or
command changed. §4 now says plainly that **a drift check cannot tell you the
generator is wrong** — it proves an artefact is current, never that it is
right — and §6's checklist tells the next chart author to take the component
name from design, add it to `DESIGN_CATALOG`, and leave guidance unset when no
design page exists.

**The gate was blind here in the way this log keeps recording.** Both catalog
artefacts were re-rendered and diffed, and both were internally consistent with
a generator that agreed with neither the design nor, in the Markdown's case,
itself — it simply did not publish the fact. A drift check compares an artefact
to its own generator; it cannot tell you the generator is wrong. Only a second,
independent declaration can, which is why the design catalog's six names are
checked in as a literal and asserted to cover every registered view.

## 2026-09-21 — GGU-55: chart primitives and the attribution waterfall

**Spec:** `specs/frontend/0002-chart-primitives-and-waterfall.md` ·
**ADR:** ADR-L D-13, D-14, D-15 · **Design:** GGU-42

### Code

A fifth workspace package, `packages/finance_charts`: `LinearScale`,
`BandScale`, readable tick steps, and `WaterfallLayout.of(steps, width,
height)`. Pure Dart, so it runs under `dart test` and its output is asserted
**arithmetically** rather than looked at. `app/lib/charts/` holds the
`CustomPainter`, the `ChartPalette` theme extension and the measured
`ChartTokens`; `app/lib/components/attribution_waterfall/` binds
`attribution.waterfall.v1`.

**No charting library, and the reason is not taste.** `fl_chart` and `graphic`
were both proposed. Both generate their own axis and tooltip labels by
formatting the values they are handed — prohibition N-1 broken silently,
inside a dependency, on the one product invariant this showcase exists to
demonstrate. A library that ships its own `NumberFormat` cannot be made to
obey a rule this repository enforces by grepping for `NumberFormat`. What is
worth having from d3 is its arithmetic, not its renderer, and that is ~350
lines.

### Harness

Three things changed and each was a gate that was weaker than it read.

- **`ViewPayload` gained exactly one numeric accessor, and the rule that said
  it never would is now wrong.** `contract-binding.md` said *"exposes no
  numeric accessor … do not add it back"*. That sentence was right about a
  `json` getter and too broad about a named reader: the contract keeps a raw
  `amount` beside every `*Display` string **so a chart can be drawn from it**
  (N-4 says so in the same file), and the value-to-pixel mapping cannot live
  on a server that does not know the width the client will be laid out in.
  `raw_decimal.dart` is allow-listed **by path**, the same shape as
  `jsonDecode` in the transport, and a second test asserts the exemption set
  has exactly one member. Mutation-checked: moving `double.tryParse` into
  `view_payload.dart` turns it red.
- **`check_coverage.dart` reported success on an empty walk.** Run where
  `app/` and `packages/` do not exist it printed `coverage ok — 0 lib file(s)
  accounted for` and exited **0**. Every assertion in it is universally
  quantified over the files it found, so the empty set satisfied all of them:
  the gate was green precisely when it was checking nothing. This is the same
  defect `repo.spelling` had, and it now takes the same fix — a check that
  cannot report success on an implausibly small input. `frontend/tool/` had no
  tests at all; `frontend/test/tool/` now covers it and `make test-tool` runs
  it — including a suite that **spawns the script** and asserts its exit code,
  because asserting that the walk returned an empty map proves the
  precondition and not the failure. `check_file_budget.dart` was not scanning
  `test/` either, so the suite over the gate's scripts would itself have been
  exempt from the budget.

  **GGU-69 found and fixed the same defect independently**, on `develop`,
  while this branch was open — two people tripping over one vacuous gate in a
  week is the strongest argument yet for the anti-vacuity idiom. The merge
  keeps develop's wording for the guard and adds the tests it did not have.
- **Goldens compare with a tolerance (ADR-L D-15).** A raster is not portable:
  the same widget anti-aliases differently on a laptop and on the Linux
  runner, so a byte-exact golden generated locally is a check that fails on CI
  for a reason that is not a defect — and the fix everyone reaches for is to
  stop running it. 0.5 % of pixels may differ. That is safe only because the
  geometry is proved exactly and separately; the mutation check changes one
  scale's interval count and watches fourteen geometry assertions **and** all
  three goldens go red together.

`frontend/0001` OD-1 is **closed**: `docs/catalog/view-catalog.snapshot.json`
is on `develop` (GGU-53), so component tests read it instead of a checked-in
copy, and `catalog_contract_test.dart` asserts every registered component's
view id and A2UI name are ones the backend publishes — the client half of the
rename that GGU-53 found on the backend.

### What the next person should know

- **The measured palette is not the one that was circulating.** Two of five
  values passed around informally were wrong: the dark surface is `#15161C`,
  not `#14151A`, and the dark neutral bar is `#6F7280`, not `#4B4D57`. Read
  the rendered DOM, do not trust a list.
- **The router no longer hard-codes a view id, and that is not this branch's
  doing.** GGU-69 landed on `develop` while this was open and fixed it the
  better way: the route carries no ids, `PortfolioViewsPage` reads them from
  the registry, and a registered component is reachable *by construction*.
  This branch merged that and kept its own half — `catalog_contract_test.dart`,
  which checks the registry against the backend's published catalog. Two
  halves of one defect, found from two directions in the same week.
- Three things the design asks for have no field in the contract: a signed,
  coloured net pill, the tooltip's price-and-share line, and which annotation
  is the net. They are OD-2 and OD-3, not omissions.

## 2026-09-21 — GGU-61: the order ticket, and the round trip that recomputes it

**Spec:** [`specs/frontend/0006-order-ticket.md`](../specs/frontend/0006-order-ticket.md).
`order.ticket.v1` (component `OrderTicket`) is the catalog's only interactive
surface, and the only place the product's central claim is either demonstrated
or quietly broken. An edit changes a **declared option** and re-requests the
same view; the client computes no figure and reads no raw member.

### What changed in the code

- `app/lib/components/order_ticket/` — the binding, the card, the impact
  panel, the controls, and `changedFigures`, which decides what to *mark* by
  comparing display **strings** before and after. No subtraction, no sign: the
  client still cannot tell which way a figure moved, and does not need to.
- `app/lib/features/order_ticket/` — bloc, page and view. The bloc owns the
  option map, debounces (300 ms, trailing, injected so a test drives it), and
  guards against a superseded response landing after the one that replaced it
  by comparing the in-flight options map **by identity**.
- `ViewPayload.strings(path)` — the contract publishes `inputs[].choices` as an
  array of strings, which `rows()` cannot read because it requires objects. The
  reader simply had no accessor for it.
- `/order-ticket` in the router table, and diagram 12 gained the edge that
  goes with it.

### What changed in the harness

- `binding_rules_test.dart`'s literal-path regex now names `strings` alongside
  `text`/`optionalText`/`rows`/`geometry`. **An accessor added to the reader
  and forgotten in that regex is a hole in N-5 exactly the width of the new
  method** — so the list is now kept in step with the class, and the regex was
  mutation-checked on its own (a variable path goes red, a literal stays
  quiet).
- `frontend/SECURITY.md` gained a threat note: this is the first surface where
  user-typed input *leaves* the client, and it leaves only as a declared
  option's value, encoded by `Uri.replace`. There is no client-side validation
  and that is deliberate (N-8) — a rule beside the server's is a second
  declaration that drifts, and an editable bundle cannot enforce one anyway.

### What the next person should know

- **The design and the frozen contract are two different components sharing a
  name, and this is not a detail.** `Catalog_OrderTicket.dc.html` draws a
  *multi-leg equity* order — NVDA/AVGO/AMD, `legs[]`, `impact.estShares`,
  `cashRemaining`, `constraints.maxCash` — with an `onSubmit()` and a "Review
  order" button. `order.ticket.v1` is a *single-leg crypto* ticket whose only
  figures are `quantity`, `entry_price` and `notional`, with `actions: []` and
  a disclosure saying nothing is ever placed. The visual language and the three
  states were adopted; the field inventory was not, because a client cannot
  invent a payload field (N-3). OD-1 and OD-2 carry it, and GGU-19 owns the
  resolution. **If the design is what ships, this needs an `order.ticket.v2`.**
- **Zone 3's prompt fragment tells the client to recompute** — *"let the client
  recompute impact on edit"* — and the mock does exactly that
  (`'$' + l.price.toFixed(2)`). A mock computing its own numbers is
  unremarkable; a **system-prompt fragment** saying so is a defect, because it
  ships to the model and contradicts the one invariant this showcase exists to
  demonstrate. OD-3. Raised, not followed.
- **Rendering a `.dc.html` artboard over `file://` gives you an inert
  snapshot.** The preview tool rewrites the page to a `data:` URL, so the
  relative `./support.js` never resolves, the bundle never boots, and Zone 1
  shows `{{ l.symbol }}` where the figures should be — while the *static*
  prose in the page header reads perfectly, which is what makes it convincing.
  Serve the directory over HTTP instead (the sandbox denies `socket.bind`, so
  that one command needs the sandbox off). Every measured value in spec 0006
  §6 AC-16 came from the HTTP render; the first set, taken from `file://`,
  was discarded. **A pixel-perfect claim built on unbound placeholders is
  indistinguishable from a correct one.**
- **`ViewComponent.build` has no slot for a callback**, so an interactive
  surface cannot go through `ComponentHost`. `OrderTicketView` builds its card
  directly and attaches `onOptionChanged` — and therefore has to repeat what
  the host does with a `PayloadContractException`. It did not, at first: a
  contract violation was a red screen until a test caught it. If a third such
  surface appears, the callback belongs on the seam, as an ADR-L amendment.
- **A test harness that keys its fixture from the code under test proves
  nothing.** The bloc suite keyed its envelope with `OrderTicketBloc.viewId`
  and looked it up with the same constant, so a typo agreed with itself. The
  envelopes are now keyed from the **catalog snapshot** while the bloc is given
  the **component's** id — two declarations that must match. The constant is
  gone: the page passes the component's `viewId`, so N-6's "a literal in one
  place" holds again.
## 2026-09-21 — GGU-93, GGU-94: the evidence a PR carries gets a field for what was not run

**Spec:** none. This is a harness change, recorded where the harness is
recorded: the rule in `.claude/rules/backend/sdd.md`, the CI rule in
`.claude/rules/ci-conventions.md` §5, and this entry. A
`specs/backend/NNNN-*.md` would have been the wrong home — nothing here is a
backend feature, no endpoint or DTO moves, and the decisions belong to the
process rather than to the product. `sdd.md`'s own decision table says so: *"a
rule the agent must follow every time"* goes to `.claude/rules/**`, *"what
changed in an iteration and why"* goes here.

**Test decision:** one new suite, `scripts/tests/test_check_manual_run.sh`,
registered as `repo.manual-run`. It asserts four rejections and one acceptance,
because the defect being fixed is *evidence that cannot be distinguished from
real evidence* — and a check nobody has seen reject reproduces it exactly.

### One defect, seen twice

GGU-93 is the runtime half: a manual run that does not say which build answered.
GGU-94 is the toolchain half: a gate that cannot run, announcing itself as a
formatting diff. Both are the same sentence — **the evidence format has no
field for what was not run**, so an incomplete verification and a complete one
produce identical-looking PR bodies. Both tickets' AC-5 anticipated being done
once; they were.

### What already existed, and was not read

`GET /health` has reported `<version>+<short sha>` since spec `backend/0007`
AC-5 — `APP_RELEASE` → `Settings.app_release` → `core/release.py` →
`HealthService`. **Nothing needed building.** Two things were wrong around it:

1. `docker-compose.yml` hard-coded `APP_RELEASE: local`, so the local stack —
   the one a manual run actually uses — could not name its own commit. It now
   reads `${APP_RELEASE:-local}`, and the documented way up is
   `APP_RELEASE="$(git rev-parse --short HEAD)" docker compose up --build`.
2. Nobody read it. The deployed dev service was answering `0.1.0+9a94346`,
   **26 commits behind `develop`**, while the Flutter client was being built
   against it — no GGU-53 catalog snapshot, no GGU-78 surface actions, no
   GGU-90 agent-turn fixes. The identity was on `/health` the whole time.

### The correction worth keeping: ancestry is too weak

GGU-93 AC-3 asked that the reviewer check the manual run's sha is *an ancestor
of the PR's head*. Implemented literally, that would have **passed the pull
request that produced the ticket**: PR #69's branch was cut from the stale
commit, so the stale commit was a perfectly good ancestor. Ancestry proves the
build is from this line of history; only identity with the head proves it
contains the change under review. `scripts/check_manual_run.sh` therefore has
three verdicts — head (pass), ancestor (fail, *"it ran and it did not exercise
this branch"*), anything else (fail).

### And the reviewer instruction is a script, not a sentence

`.claude/agents/*-reviewer.md` do not ask the agent to compare shas by eye.
They run one command and quote it. An LLM reviewer *can* run `git merge-base
--is-ancestor`; what it cannot be relied on to do is remember to. The same
reasoning that produced `repo.gate-pairs` — three instances of a reviewer being
asked to be careful — applies here at the first instance, because the first
instance already cost a retracted bug report and a closed PR.

### GGU-94: the pin had no local reader

`FLUTTER_VERSION: "3.47.5"` lived only in `frontend-ci.yaml`. The floor
`sdk: ^3.13.0` in `frontend/pubspec.yaml` is not consulted by `dart format`, so
Homebrew's `dart-sdk 3.12.1` ran the gate happily and reported three tracked
files as unformatted — 3 changed / exit 65 under 3.12.1, 0 changed / exit 0
under the pin, on the same commit. The version now lives in
`frontend/.fvmrc`, read by `frontend/tool/check_toolchain.sh` and by
every SDK-setup step in the workflow, and `frontend.toolchain` is the **first**
entry of the frontend gate.

`.fvmrc` over `.fvmrc`: plain text that `cat` and the CI action both
read, with no implied claim that fvm is the supported install path.

### What the next person should know

- **`flutter --version` crashes in an agent sandbox** and `dart --version` from
  the same `bin/` does not. The cause is the tool's telemetry writer failing to
  delete `~/.dart-tool/dart-flutter-telemetry.log`, inside flutter's own error
  handler — a secondary crash that hides whatever the first failure was. The
  preflight uses `flutter --version --machine --suppress-analytics`, which also
  returns `dartSdkVersion` and `flutterRoot` as JSON. A preflight that crashes
  is worse than no preflight.
- **macOS `mktemp -d` with no template ignores `TMPDIR`** and uses the confstr
  directory, which is outside the agent sandbox's write set. Same command, two
  behaviours, red only on a laptop. Always pass a template.
- **`repo.manual-run` needs history.** Its fixtures are `HEAD` and `HEAD~2`, so
  its `repo-ci` job checks out with `fetch-depth: 0` and the suite says so
  rather than failing obscurely on a shallow clone.
- **Agent worktrees keep leaking machine state into a public repository.**
  `.gitignore` now covers `.claude/launch.json` (commit `5f6e09c` shipped one
  naming a path on one laptop) and `.design-refs/` (the design bundles only
  render from inside the project folder).
- **Making agent worktrees track `develop` automatically is still not done**,
  deliberately — GGU-93 puts it out of scope. It is the better *preventive*
  fix and it is a different ticket: this one is about evidence being
  **checkable**, not about the mistake being impossible. A process that only
  works when nobody is behind is the thing being replaced.

### The review round, which found the same defect inside the fix

Both reviewer agents flagged the same blocker, and they were right: **the first
version of this change added a second pin file.** `frontend/.fvmrc` was already
tracked, already contained `{"flutter": "3.47.5"}`, and was already cited as the
pin by `frontend/README.md` and `docs/DEV_HARNESS.md`. The branch added
`frontend/.flutter-version` beside it and then asserted, in nine places, that
the version lived in one home and nowhere else. Two machine-readable pins free
to drift is precisely the defect GGU-94 exists to remove, recreated one file
over, by the change that removes it.

`.fvmrc` is now the single home and `.flutter-version` is gone. The lesson is
not "look harder": it is that the claim was **prose**, so nothing could check
it. `scripts/check_gate_pairs.sh` now also asserts that no workflow sets
`FLUTTER_VERSION` and that no second tracked pin file exists — §5's third
question, machine-checked like the first.

Four more findings worth recording, because each was a case of the new
mechanism failing its own standard:

- **The documented bring-up produced a value the checker rejected.**
  `core/release.py::resolve_release` returns `APP_RELEASE` **verbatim** — the
  `<version>+<sha>` shape is composed by `infra/scripts/deploy_cloud_run.sh`,
  not by the app. So `APP_RELEASE="$(git rev-parse --short HEAD)"` gave
  `"version":"5b942f1"`, with no `+`, and the check read no identity at all. A
  developer following `CLAUDE.md` verbatim would have failed the check they
  were told to pass. The documented command is now `local+$(…)`, and the suite
  has a case pinning the bare-sha failure so the docs cannot drift back.
- **The check contradicted the rule it enforces.** `sdd.md` says a deployed run
  that is behind is pasted "as well, never instead"; the script looped over
  every identity and failed the body for the context one. It now asks whether
  **any** identity is the head, and prints the rest as context.
- **The identity parse matched any `+<hex>` in the body**, so a line like
  `v1.2.3+abc1234` sank a good pull request. It is scoped to the `"version"`
  field of a `/health` payload.
- **Nothing ran the check against a real PR body.** `repo-ci` now does, on
  every pull request, pointed at `github.event.pull_request.head.sha` — a PR
  checkout's `HEAD` is the ephemeral merge commit, which is not what the manual
  run was served by. A body with **no** identity exits 3 and is reported rather
  than failed: `sdd.md` explicitly allows a declared, reasoned "not run", and
  no grep can tell that from an omission. That one judgement stays with the
  reviewer; everything a machine can decide is decided by one.

And the preflight got the suite it should have shipped with
(`frontend/tool/tests/test_check_toolchain.sh`, `frontend.toolchain-test`). It
stubs `flutter` and `dart` on `PATH`, so it runs in a second on a machine with
no Flutter at all — which matters because it is the **first** step of the
frontend gate, so a false failure blocks everything behind it, and because on a
runner it can never be seen rejecting: CI always installs the pin.
