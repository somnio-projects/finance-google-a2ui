# 0033 — The simulated assistant, offline

- **Area:** backend
- **Status:** In progress
- **Ticket:** _unassigned — no GGU number exists for this yet; none is invented here (see 0025 §6)_
- **Also:** [0006](0006-agent-host.md) (the turn loop, `NullModelClient`, AC-8), [0022](0022-surface-actions.md) OD-1 (the agent cannot invent a chip), [0029](0029-the-turn-recommends-its-chips.md) OD-1 (the null path is the one every local stack runs), [0008](0008-attribution-tool.md) · [0011](0011-holdings-tool.md) · [0013](0013-simulate-sale-tool.md) · [0014](0014-payoff-tool.md) (the tools the script calls), [ADR-E](../../docs/adr/ADR-E-money-representation.md) D-2, [ADR-K](../../docs/adr/ADR-K-response-shaping.md) D-12
- **Owner:** Lautaro Bertuzzi · **Date:** 2026-09-22

## 1. Problem

Every local stack runs without `GEMINI_API_KEY` — the key is a Secret Manager
value (ADR-G), and `env.example` leaves it commented out on purpose. Without it
the factory selected `NullModelClient`, whose one sentence is *"The assistant is
running without a model provider, so it can only confirm that the service is
up."* Honest, and it was the whole of the Assistant tab: no tool ran, no
surface was composed, and the product's one idea — an agent that answers a
portfolio question with UI — was invisible on the machine of everyone who
reviews it.

Meanwhile nothing the design's three flows need is missing. Flow A (*What
moved my portfolio today?*) is `compute_attribution` and the waterfall; Flow B
(*If I sell $20k of NVDA, what's the tax hit?*) is `simulate_sale` and the
tax-lot table; Flow C (*Put about $10k into semiconductors, keep it
diversified.*) is `payoff`; the four curated chips (0022, 0029) each name one
of the same tools. Every one is deterministic and already returns
pre-formatted `*Display` strings. The only thing a model contributes to those
turns is *choosing* the call and *phrasing* the sentence — and both can be
written down.

## 2. What ships

- **`ScriptedModelClient`** (`infra/model/scripted_client.py`), the
  `ModelClient` the factory selects when no key is configured. It reads the
  last user message, looks it up in a table, and answers in two steps exactly
  as a model would: the table's tool calls first, then — once the loop has fed
  the results back — the table's sentence with the tools' own strings in its
  holes. A prompt outside the table gets `UNCONFIGURED_MESSAGE`, unchanged.
  Telemetry records the model as `scripted`; `calls` still records the system
  prompt, the messages and the tool specs, so the loop's tests read it like
  the null client.
- **The table** (`infra/model/demo_script.py`), keyed by normalised prompt:

  | Prompt | Tool call(s) | Surface(s) | Says |
  |---|---|---|---|
  | *What moved my portfolio today?* (Flow A) | `compute_attribution {window: 1d}` | `attribution.waterfall.v1` | *Your portfolio is {trend} {changeDisplay} ({changePctDisplay}) today. Here's what drove it:* |
  | *If I sell $20k of NVDA, what's the tax hit?* (Flow B) | `simulate_sale {symbol: NVDA, amount_usd: "20000", lot_method: FIFO}` | `taxlots.table.v1` | the quantity, proceeds, realised P/L and its short/long split, then *The tax itself depends on your rate, which I don't apply; nothing is traded.* |
  | *Put about $10k into semiconductors, keep it diversified.* (Flow C) | `payoff {symbol: NVDA, size: "10000", size_in: usd, side: buy}` | — (0014 OD-7) | the notional, units, entry and break-even, then *a ticket spread across several names is not available yet.* |
  | chip `allocation` — *Show me what I hold and how my portfolio is allocated.* | `get_holdings_summary {}` | `holdings.allocation.v1` | the market value and unrealised P/L, *Here is how it is allocated, largest first:* |
  | chip `biggest-drivers` — *Which holdings drove my performance the most over the last week?* | `compute_attribution {window: 7d}` | `attribution.waterfall.v1` | the week's move, *The holdings that moved it most are drawn first:* |
  | chip `tax-lots` — *Show me the tax lots a sale would consume and what it would realise.* | `simulate_sale` (the Flow B sale) | `taxlots.table.v1` | *As the example, … split by term below. Nothing is traded.* |
  | chip `why-did-i-move` — *Why did my portfolio move over the last week?* | `compute_attribution {window: 7d}` | `attribution.waterfall.v1` | *Your portfolio is {trend} … over the last week. Here's what drove it:* |
  | `drill.attribution.v1` for each of the 17 market symbols — *Break down the contribution of {S} in more detail for the same window, and show the result.* | `compute_attribution {window: 7d, symbols: [S]}` | `attribution.waterfall.v1` | *On its own, {S} contributed {changeDisplay} ({changePctDisplay}) over the last week; here is its waterfall.* |

  The chip and drill keys are produced by calling the actions' own `compose`
  (`ask.suggested.v1`, `drill.attribution.v1`) over `DECLARED_KEYS` and
  `MARKET_REFERENCE`, so the table cannot drift from the prompt a tap sends.
  `{trend}` is the tool's own `up`/`down` token; every other hole is a
  `*Display` string or a label (`symbol`, `lotMethod`, `name`).
- **`infra/model/script.py`**: `Script`, `ScriptedCall`, `normalise` (case,
  runs of whitespace, terminal `.?!`), and `fill`, which copies string leaves
  of the fed-back results into `{dotted.path}` holes and answers
  `TOOLS_FAILED_MESSAGE` — *The tools could not complete that request, so
  there is nothing to show yet.* — the moment one hole has no string to fill
  it (a `tool-failed`, a `position-too-small`, a `None` percentage).
- **`build_model_client`** returns `ScriptedModelClient()` for a missing key
  and `GeminiModelClient` otherwise; `NullModelClient` stays as the test
  double it always also was, and its `UNCONFIGURED_MESSAGE` is what the
  scripted client says outside its table.

**Extended when the views land.** Two of the design's surfaces have no tool
that aims at them yet, and the script does not pretend otherwise:

| Design shows | Today's script | Extended when |
|---|---|---|
| Flow B's second card, the method-by-method comparison | one `taxlots.table.v1` under FIFO | a tool emits `scenario.comparison.v1` (the projection exists — 0017 — but no tool renders it; the model cannot ask for a view a tool did not produce) |
| Flow C's multi-leg order ticket across NVDA / AVGO / AMD | one `payoff` leg on NVDA, no surface | `order.ticket.v2` and its tool land (in progress on a sibling branch); the entry then adds the ticket's call and drops *not available yet* |
| The drill's "same window" | the default `7d` window, and the sentence says *over the last week* | the client sends the window it drilled from as a declared argument of `drill.attribution.v1` |

## 3. Rulings

- **OD-1 — exact match, after normalisation, and nothing looser.** A scripted
  model that matched on keywords would be a classifier nobody wrote a test
  for, answering *"sell everything"* with a tax-lot table because it saw
  *sell*. The table's keys are the sentences the backend already owns — the
  registered chips, the composed drill, the design's three artboard
  questions — and case, whitespace and a trailing `?` are the only things
  forgiven, because they are the only ways a typed question differs from the
  designed one without meaning something else. A paraphrase gets the
  unconfigured sentence, which is true: no model is configured.
- **OD-2 — no free text; every figure is a copy.** The sentences are server
  text with holes, and a hole is filled only by a *string* the tools returned
  in this turn, addressed by path. There is no arithmetic, no formatting and
  no interpolation of anything the tool did not say — an integer count or a
  list cannot fill a hole, and an unfillable hole replaces the whole sentence
  with `TOOLS_FAILED_MESSAGE` rather than leaving a bracket or a guess. This
  is spec 0006 AC-8 with the model removed: the one party that could have
  paraphrased a number is a table.
- **OD-3 — the drill answers the default window.** The client is stateless on
  purpose (0006 §3.1) and matches the last user message; reading the previous
  turn's `window` out of the history would be inference the exact-match rule
  forbids. The sentence therefore says *over the last week*, which is what was
  computed. The honest fix is a declared argument on the action, recorded
  above.
- **OD-4 — a real key switches the script off, entirely.** `build_model_client`
  is a two-way choice: a configured `GEMINI_API_KEY` yields `GeminiModelClient`
  and the table is never consulted. There is no mixed mode where a known
  prompt is scripted and an unknown one goes to the model, because that would
  put two authors behind one voice and make a reviewer's transcript
  unreproducible without knowing which one answered. The model name in
  telemetry (`scripted` vs the Gemini id) is how a transcript says which.
- **OD-5 — the script picks tool calls; the tools decide everything else.** No
  render intent is scripted. The waterfall, the donut and the tax-lot table
  appear because the *tool* emitted them and the projection registry accepted
  them (ADR-K D-11/D-12, GGU-84), and `payoff` draws nothing because it emits
  nothing (0014 OD-7). A script cannot aim a view at an answer, which is the
  same bound the real model has — and why Flow C shows no ticket until a tool
  produces one.
- **OD-6 — nothing here is a chip.** The scripted turn ends with the same
  `suggestions` the adapter chooses from the curated table minus the prompt
  just run (0029 OD-1); the script neither adds nor reorders one (0022 OD-1).

## 4. Test decision

Unit, `tests/unit/infra/model/`: `normalise` over the design's sentence, its
case/whitespace/punctuation variants and a paraphrase that must miss;
`flatten` keeps only string leaves; `fill` copies, lets a later result win,
and answers the fallback for an absent field, an integer leaf and a list
leaf. The client: records what it was sent, answers the unconfigured
sentence for no question, an unknown prompt and an unknown follow-up after a
scripted history, asks for its calls in order, and says the filled sentence
— or the failure sentence — once results are present. The table: chip keys
equal `DECLARED_KEYS`, every drill over `MARKET_REFERENCE` is a key, the
three flows are keys, the table is exactly those three sources, every call
names a tool in the discovered registry, and every hole is a `*Display`
string or a named token.

Unit, `tests/unit/services/test_scripted_turns.py`: **every key of the table
is run as a turn through `AgentService`** with the real tools over the seeded
`InMemoryPortfolioProvider` and the real projection registry; each yields the
tool's surfaces in order, two iterations, no exception, no unfilled hole, and
every hole's value verbatim from the result the loop fed back. Flow A is
pinned to the design's sentence with the seed's figures (*+$3,240.18 (0.68%)*,
spec 0025 §2); Flow B's intent names NVDA under FIFO; Flow C draws nothing and
says so; a prompt outside the table still answers `UNCONFIGURED_MESSAGE` with
`model=scripted` in the turn metric. The factory test asserts no key →
`ScriptedModelClient` and a key → `GeminiModelClient`, as before.

Not run: a browser pass over the Assistant tab — there is no `backend/.env`
in this worktree and the compose stack was not started. The turn-level suite
is the same path minus HTTP and SSE, which spec 0010's suite covers with the
null client.
