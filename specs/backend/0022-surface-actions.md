# 0022 — Surface actions: what a generated surface is allowed to send back

- **Area:** backend
- **Status:** Draft
- **Ticket:** [GGU-78](https://somniosoftware.atlassian.net/browse/GGU-78) (backend half of [GGU-15](https://somniosoftware.atlassian.net/browse/GGU-15); consumed by GGU-31 drill-down and GGU-32 chips) · **Related specs / ADRs:** 0005 (presentation layer), 0006 (agent host), 0010 (A2A surface), 0018 (order ticket), [ADR-K](../../docs/adr/ADR-K-response-shaping.md), [ADR-J](../../docs/adr/ADR-J-rest-api-and-a2a-surface.md), [ADR-D](../../docs/adr/ADR-D-a2ui-streaming-transport.md) · rules `.claude/rules/backend/presentation.md`, `.claude/rules/backend/api-design.md`
- **Owner:** Lautaro Bertuzzi · **Date:** 2026-09-20

---

## 0. Read this first: most "actions" are not actions

> **If an interaction can be expressed as a change to a declared option, it needs
> nothing in this spec. Do not build anything.**

The round-trip already exists and it is already safe. A projection publishes a
bounded, documented options model (ADR-K D-3); both callers — the client through
`?view=`/`POST /v1/view-renders`, and the model through a render intent — resolve
through the **same registry and the same options model** (D-11), and an unknown
view, an undeclared option or an out-of-range value is **rejected** with the
rejection counted in telemetry (D-12). `order.ticket.v1` already ships the
declaration side: `inputs[]` publishes one `TicketInput` per editable option, and
**an editable field is a payload field named exactly as the option that sets it**
(spec 0018 OD-1). Editing is re-rendering.

That covers sorting, filtering, `top_n`, `window`, locale, precision, currency,
field trimming, changing an order's side or size — every interaction in the
current six-component catalog **except two**.

The one-line test this spec hands to the next person:

> **If the answer is the same view with different numbers, it is an option.
> If the answer is a new agent turn, it is an action.**

Only the second case is new, and this spec exists to keep it from becoming a
second, looser copy of the first.

## 1. Problem

Two interactions in Epic 5 do not fit the options mechanism:

- **GGU-31 — drill-down.** Tapping a waterfall segment must make *the agent
  recompose at that depth*: new narration, possibly a different component, a
  back affordance, a graceful leaf case. Its acceptance criteria are about an
  agent turn, not about a chart redrawn with a different parameter.
- **GGU-32 — entry chips.** Tapping a chip must *start a flow*. That is a user
  turn that nobody typed.

Today there is no way for a surface to send anything back. The A2A envelope
(`backend/src/app/schemas/a2a.py`) accepts exactly one part kind, `text`; the
stream emits `render-intent` events outward and nothing comes in except prose.
So a client that wants to express "go deeper on DOGE" has exactly one option
available to it: **make up a sentence and send it**. That is the failure mode
this whole project argues against — an unbounded string the backend then
interprets — arriving through the front door because no bounded alternative was
offered.

The hard constraint is ADR-K **D-3**: *no free-form template, expression or field
path is ever interpreted from client or model input.* An action must be as
declared as an option is.

There is a second, structural problem. **ADR-J D-6** says extending the JSON-RPC
surface "needs a decision recorded here". Anything in this spec that touches the
A2A envelope therefore cannot merge as a spec alone — see §8 OD-6.

## 2. Scope

**In**

- `app/actions/` — a new **framework-free** package, peer of `presentation/`,
  holding the action contract and the action registry:
  - `contracts.py` — `SurfaceActionSpec` (id, label, args model, `prompt()`
    builder, `mutating`, `audited`) and the `SurfaceAction` Protocol.
  - `registry.py` — `ACTIONS`, local `register(...)`, `UnknownActionError`;
    **refuses to register `mutating=True`** (§5).
  - `resolve.py` — `validated_args(action, args)`, mirroring
    `presentation/resolve.py`: names the offending argument, never its value.
  - `declared.py` — `SurfaceActionRef`, the *declaration* a payload publishes,
    derived from the args model's own JSON schema (the `declared_inputs`
    pattern from `presentation/tickets.py`, generalised).
  - `actions/drill_attribution.py`, `actions/ask_suggested.py` — the two
    registered actions, each with its own module and its own `register(...)`.
- `app/services/surface_action_service.py` — resolve + validate an inbound
  action, produce the turn input, emit telemetry, write the audit event when the
  action declares one.
- The A2A envelope: a second `MessagePart` kind, `data`, bounded, carrying
  `{action, args}` and nothing else (§3).
- `app/presentation/` — projections may declare `actions: tuple[SurfaceActionRef, ...]`
  on their DTO and map them into the A2UI surface props through their own
  adapter. `attribution.waterfall.v1` is the first to declare one.
- `ViewDescriptor.actions` in `GET /v1/views`, and the actions inventory in the
  generated `docs/catalog/CONTRACT.md` (gated by `make catalog`, spec 0019).
- Feature flag `surface.actions`.

**Out**

- **Mutating actions of any kind** — no broker, no execution, no order resource.
  The registry refuses them by construction (§5, OD-4). Consistent with 0018 OD-2.
- **Idempotency keys.** Nothing in scope mutates, so at-least-once delivery is
  safe; the cost of a duplicate is a duplicate turn. OD-5.
- **Persisting actions, surfaces or a surface/action history.** No table, no
  migration. A back affordance is client state (GGU-31 §Technical Design) —
  binding an action to "the surface that rendered it" would need a server-side
  surface store, which is the "ticket session" 0018 OD-1 already rejected. OD-3.
- **Scoped attribution itself** — `compute_attribution` taking a driver argument
  is GGU-36's contract (spec 0008), not this one. This spec delivers the way the
  request arrives; the deeper numbers are the tool's job, and the leaf case is
  answered there.
- **The client**: the chip widget, the tap handler, the back stack, debouncing a
  tap during a pending turn — GGU-31/GGU-32, client side.
- **A REST action resource.** Decided against, §3.2 and OD-2.
- **The `GGU-47` render-intent gap.** `RenderIntentService` exists and has no
  agent call site (`services/render_intent_service.py` docstring says GGU-47
  calls it; nothing does). Real, adjacent, and not this ticket — flagged in §9.

## 3. API contract

### 3.1 What a surface is allowed to send

**An action id it did not invent, plus arguments drawn from bounds the same
payload published.** Nothing else. Three properties follow, and each is a test:

1. **The id is registered.** `^[a-z][a-z0-9]*(\.[a-z0-9-]+)+\.v[0-9]+$`, resolved
   in `ACTIONS`. Unknown → rejected. The client cannot name a behaviour that
   does not exist, exactly as it cannot name a view that does not exist.
2. **The arguments are a declared pydantic model**, `extra="forbid"`, every field
   bounded (`Literal`/`ge`/`le`/`max_length`/`pattern`), defaulted, described,
   exemplified. Undeclared or out-of-range → rejected.
3. **The client sends no prose and no structure.** It sends an id and scalars.
   What the turn actually receives is composed **server-side**, by the registered
   action's own `prompt()` — a constant in backend code with validated arguments
   substituted into it. The client supplies values; it never supplies the
   sentence, the field path, the tool name or the view.

Point 3 is the whole design. A template the *client* sends is a free-form DSL
(D-3, and ADR-K's rejected alternatives list). A template the *backend* owns,
filled with values a pydantic model has already validated, is an f-string in a
service — which is what every other endpoint here already is.

### 3.2 Where it goes: back into the A2A turn

**Decision: the A2A surface, as a new typed message part. No new REST resource.**

| | A2A turn (**chosen**) | `POST /v1/surface-actions` (rejected) |
|---|---|---|
| What the caller wants back | streamed surfaces + narration | a 201 with nothing renderable, then a stream anyway |
| Round trips | one | two |
| Error shapes the client parses | **two** (RFC 9457 pre-envelope, JSON-RPC in-protocol) — unchanged | **three** |
| Terminal state | `input_required` / `completed` already defined (ADR-D D-3) | undefined |
| Failure mid-turn | already emitted inside the stream | would need inventing |
| Is it a resource? | n/a — it is a message | no. "Create an action" is RPC wearing a noun; `api-design.md` forbids the escape hatch and creating a resource nobody can `GET` is that escape hatch with extra steps |

Every action in scope produces exactly one observable thing: **a new agent turn
that streams surfaces**. That is what `message/stream` is. Routing it through
`/v1` would create a resource whose only purpose is to make the client open the
stream it was going to open anyway, and would hand the Flutter client a third
error shape to parse — the specific harm GGU-78 names.

**Wire shape** — `POST /` (unchanged path, auth, method):

```jsonc
{
  "jsonrpc": "2.0", "id": "req-1", "method": "message/stream",
  "params": { "message": {
    "role": "user",
    "messageId": "m-42",
    "contextId": "c-7",
    "parts": [
      { "kind": "data", "data": {
          "action": "drill.attribution.v1",
          "args": { "driver": "DOGE" } } }
    ]
  } }
}
```

`kind: "data"` is A2A's own `DataPart`, so this is the protocol's shape rather
than ours (OD-6 still applies: it is an extension of what we accept).

**Bounds on the new part** (`schemas/a2a.py`, all `extra="forbid"`):

| Field | Bound |
|---|---|
| `data` | object, exactly the keys `action` and `args` |
| `data.action` | string ≤ 64, the id pattern above |
| `data.args` | object, ≤ **8** keys, each value a string ≤ 64, an int, a bool or `null` — **no nested objects, no arrays** |
| parts per message | ≤ 16 (unchanged); **at most one `data` part**, and a message carrying one carries no `text` part |

The no-nesting rule is deliberate: a nested object is where a path expression
hides. Every declared argument today is a scalar, and an action that genuinely
needs structure amends this table with its reason.

**Errors** — the shapes that already exist, nothing new:

| Situation | Answer |
|---|---|
| No token, rate limited | RFC 9457 problem document at its real status (pre-envelope, unchanged) |
| Malformed envelope / unparsable part | JSON-RPC `-32602` invalid-params, **HTTP 200** (unchanged) |
| Unknown action id | JSON-RPC `-32602`, HTTP 200, fixed message `UNKNOWN_ACTION` |
| Undeclared or out-of-range argument | JSON-RPC `-32602`, HTTP 200, message names the **argument**, never the value |
| `surface.actions` flag off | JSON-RPC `-32601` method-not-found — a disabled capability is one that does not exist, mirroring the REST 404-for-feature-disabled rule |
| The turn itself fails after it starts | `status-update{failed}` + `{"kind":"error"}` **inside the stream** (unchanged, spec 0010) |

The action is validated **before** the stream opens, so a bad action is a clean
JSON-RPC error rather than a stream that fails on its first event.

**Deliberately *not* ADR-K D-12's fallback.** An invalid render intent falls back
to the endpoint's default projection, because a wrong-looking chart beats no
chart. An invalid action has no sensible default — "go deeper on ‹something the
backend refused to read›" cannot be guessed — and silently running a different
turn than the user tapped is worse than saying no. Rejection is terminal here,
and that difference is stated because a reader will otherwise assume symmetry.

### 3.3 The two registered actions

| Action | Args | What `prompt()` composes (server-side constant) |
|---|---|---|
| `drill.attribution.v1` | `driver: Literal[…]` — the eight curated market-reference symbols, the same source `OrderTicketOptions.symbol` reads, compared by a test | *"Break down the contribution of {driver} in more detail for the same window, and show the result."* |
| `ask.suggested.v1` | `suggestion: Literal[…]` — the registered suggestion keys | the registered prompt text for that key, verbatim |

`ask.suggested.v1` is the chip. The chip's **text lives in the backend**, keyed by
a declared id; the payload publishes `{id, label}`, the client sends the id back.
This is D-12 applied to chips — *the model picks from the registry, it never
invents*. A chip whose sentence the model authors would be model-generated text
re-entering the turn as a user message: harmless today, and exactly the shape
this project refuses to ship as a reference implementation. It also makes a tap
reproducible: the label the user read and the prompt that ran cannot drift.

Consequence, stated plainly: **the agent cannot invent a follow-up chip.** It
selects suggestion ids from a curated set. That closes GGU-32's "agent-generated
dynamic follow-ups" stretch goal. See OD-1.

### 3.4 What a surface declares

A projection that offers an action publishes it the way `order.ticket.v1`
publishes an editable option — as a descriptor derived from the args model's own
JSON schema, never hand-written twice:

```jsonc
"actions": [
  { "action": "drill.attribution.v1", "label": "Break this down",
    "arg": "driver", "control": "choice",
    "choices": ["ADA","AVAX","BTC","DOGE","DOT","ETH","LINK","SOL"] }
]
```

`GET /v1/views` gains `actions` on `ViewDescriptor` beside `options_schema` — the
same fact, published to the same catalog, rather than a second endpoint that
could disagree with the payload. `docs/catalog/CONTRACT.md` gains an actions
inventory, regenerated and diffed by `make gate` like everything else it holds.

A projection that declares **no** action produces **no** actionable prop in its
A2UI surface. That is a test, and it is what protects 0018 AC-8: the order ticket
must stay un-submittable, and adding an action mechanism must not quietly give it
one.

## 4. Data model & migration

**None.** No table, no column, no Alembic revision. Actions are validated,
dispatched into a turn and forgotten. Audit events, where an action declares one
(§5), reuse the existing `audit_events` table unchanged.

## 5. Security notes

**Authentication and authorisation.** `POST /` already resolves `PrincipalDep`
(ADR-J D-4); an action runs as the verified subject with no new scope. No new
public route.

**The declaration is the security boundary, and it is derived, not retyped.** As
in 0018 §5: a published bound the backend does not enforce is client-side-only
validation. `SurfaceActionRef` is built from the args model's JSON schema, and a
registry-walking test (`test_declared_action_bounds.py`, the twin of
`test_declared_input_bounds.py`) feeds every published bound of every registered
action back through `validated_args` — so the *next* action is covered the day it
registers, not the day somebody remembers.

**No interpretation of caller input.** The client sends an id and scalars; the
prompt, the tool selection and the view all come from backend code. There is no
path from a request body to a template, an expression, a field path, a tool name
or a view id (ADR-K D-3).

**No mutating actions.** `SurfaceActionSpec.mutating` exists and `register(...)`
raises `ConfigurationError` when it is `True`. This showcase has no broker and no
execution path; the registry refusing the whole category means nobody adds a
trade-placing action without first amending this spec and ADR-K. It is the same
honesty measure as 0018 OD-2, one level up — and it is the reason idempotency is
out of scope rather than forgotten (OD-5).

**Audit.** `audited: bool = False` per action, and the dispatcher writes
`surface_action.invoke` with `target = <action id>` only when the action declares
it. **No action in today's catalog sets it**, because neither drilling nor asking
a suggested question decides or changes anything, and filling
`GET /v1/me/audit-events` with taps would bury the identity events it exists to
show. The seam is declared and tested now so the first action that *does* decide
something inherits an audit trail rather than an omission. OD-4 records the
alternative.

**Telemetry, not content.** `surface.action.accepted` and
`surface.action.rejected`, both tagged with the **action id** (a registered
constant) — never with argument values, never with the composed prompt. Mirrors
`presentation.render_intent.rejected`.

**Rejections name the argument, never the value**, so an echoed input cannot
become a reflection vector (`presentation/resolve.py` precedent).

**Rate limiting becomes load-bearing for a new reason.** A tap is cheaper than
typing, so a chip lowers the cost of starting a turn by an order of magnitude. No
new limiter — the existing per-subject limit on `POST /` already covers it — but
it is now the only thing between a held finger and a queue of model calls, and it
is named here so it is not "tuned down for the demo".

**Known limitation carried forward.** `BodyLimitMiddleware` inspects
`Content-Length`, so a chunked body is not bounded by it (spec 0010, OD-6 there).
A `data` part does not change that; the new bounds in §3.2 limit what survives
parsing, as the text bounds already do.

Maps to `backend/docs/SECURITY.md` §input validation and §audit.

## 6. Acceptance criteria

1. **AC-1** — The spec's §0 rule holds in code: **no projection gains an action
   for an interaction expressible as an option.** A registry-walking test asserts
   that no registered action's argument shares a name with a declared option of
   any projection that declares that action. A drill-by-option is a failing test,
   not a review note.
2. **AC-2** — An action registers from its own module; adding one edits no shared
   file (the D-15 guarantee, applied to actions). Removing a `register(...)` call
   turns the suite red.
3. **AC-3** — A `message/stream` carrying a valid `data` part runs a turn whose
   input is the **server-composed** prompt for that action, and streams the
   documented event order ending `input_required`.
4. **AC-4** — An unknown action id is a JSON-RPC `-32602` at **HTTP 200**; the
   stream never opens; no fallback turn runs.
5. **AC-5** — An undeclared argument, an out-of-range argument, a nested object,
   an array, more than 8 keys, or a message carrying both a `data` and a `text`
   part is rejected the same way, and the message names the argument, never its
   value.
6. **AC-6** — For **every** registered action, every bound published in
   `SurfaceActionRef` is the bound `validated_args` enforces: every advertised
   choice is accepted and anything outside it is rejected.
7. **AC-7** — `drill.attribution.v1`'s driver enum is exactly the curated market
   reference; the two declarations are compared by a test (the 0018 AC-6 pattern).
8. **AC-8** — `ask.suggested.v1` accepts only registered suggestion keys, and the
   prompt it runs is the registered text for that key, byte for byte. The client
   cannot send prompt text through this path at all.
9. **AC-9** — `register(SurfaceActionSpec(..., mutating=True))` raises
   `ConfigurationError`.
10. **AC-10** — An action with `audited=True` writes exactly one
    `surface_action.invoke` event for the authenticated subject; the two shipped
    actions write none. No log line or metric tag carries an argument value or
    the composed prompt.
11. **AC-11** — `attribution.waterfall.v1` publishes its action in its payload,
    in its A2UI props, in `GET /v1/views` and in `docs/catalog/CONTRACT.md`;
    `make catalog` is run and the regenerated contract is committed (a stale
    contract fails the gate).
12. **AC-12** — Every projection that declares **no** action produces no
    actionable prop, and `order.ticket.v1` in particular still carries no submit,
    no endpoint and no callback (0018 AC-8 re-asserted against this change).
13. **AC-13** — With `surface.actions` off, a `data` part is `-32601`
    method-not-found and every other A2A behaviour is byte-identical to today.
14. **AC-14** — `make gate` green; `03-backend-layers.md`, `05-agent-turn.md` and
    `06-response-shaping.md` updated in the implementing PR.

## 7. Test plan

| AC | Unit test(s) | Integration test(s) |
|---|---|---|
| AC-1 | `tests/unit/actions/test_actions_are_not_options.py::test_no_action_argument_shadows_a_declared_option` | — |
| AC-2 | `tests/unit/actions/test_registry.py::test_an_action_registers_from_its_own_module`, `::test_adding_an_action_edits_no_shared_file` | — |
| AC-3 | `tests/unit/services/test_surface_action_service.py::test_a_validated_action_becomes_the_server_composed_prompt` | `tests/integration/test_a2a_actions.py::test_a_data_part_runs_a_turn_and_streams_surfaces` |
| AC-4 | `tests/unit/services/test_surface_action_service.py::test_an_unknown_action_is_rejected_before_the_turn` | `tests/integration/test_a2a_actions.py::test_an_unknown_action_is_a_json_rpc_error_at_http_200` |
| AC-5 | `tests/unit/actions/test_resolve.py` (parametrised: undeclared key, out of range, nested object, array, >8 keys, data+text) | `tests/integration/test_a2a_actions.py::test_a_rejection_names_the_argument_not_the_value` |
| AC-6 | **`tests/unit/actions/test_declared_action_bounds.py`** (whole file, walks `ACTIONS`) | — |
| AC-7 | `tests/unit/actions/test_drill_attribution.py::test_the_drivers_offered_are_exactly_the_market_reference` | — |
| AC-8 | `tests/unit/actions/test_ask_suggested.py::test_only_registered_suggestion_keys_are_accepted`, `::test_the_prompt_is_the_registered_text` | — |
| AC-9 | `tests/unit/actions/test_registry.py::test_a_mutating_action_cannot_be_registered` | — |
| AC-10 | `tests/unit/services/test_surface_action_service.py::test_an_audited_action_records_one_event`, `::test_the_shipped_actions_record_none`, `::test_no_telemetry_carries_an_argument_value` | `tests/integration/test_a2a_actions.py::test_a_tap_leaves_no_audit_event` |
| AC-11 | `tests/unit/presentation/test_attribution_waterfall.py::test_the_surface_publishes_its_drill_action`, `tests/unit/api/test_views_endpoints.py`, `tests/unit/presentation/test_contract_document.py` | — |
| AC-12 | `tests/unit/presentation/test_no_undeclared_actionable_props.py` (walks the registry), `tests/unit/presentation/test_order_ticket.py::test_the_ticket_declares_one_effect_and_no_way_to_place_an_order` | — |
| AC-13 | `tests/unit/api/test_a2a_rpc.py::test_a_data_part_is_method_not_found_while_the_flag_is_off` | `tests/integration/test_a2a_actions.py` (flag off case) |
| AC-14 | the existing OpenAPI contract tests + `catalog-check` | `make gate` |

**Mutation checks required (auth / rate limit / error masking): yes.** Three,
because this spec adds an inbound path:
1. Delete the action validation call → AC-4/AC-5 must fail (i.e. an unvalidated
   action must not be able to reach the turn).
2. Widen one `Literal` in an args model without touching its `SurfaceActionRef`
   → `test_declared_action_bounds.py` must fail (published ≠ enforced).
3. Add an argument value to a telemetry tag → AC-10 must fail.

## 8. Open decisions

| # | Question | Owner | Default if unresolved |
|---|---|---|---|
| **OD-1** | **May the agent author a chip's prompt text, or only select a registered suggestion id?** This is the product decision in this spec. | TL | **Only select.** A model-authored prompt re-entering the turn as a user message is the model inventing a payload (D-12), the label and the prompt can drift, and a tap stops being reproducible. **Cost, stated honestly:** GGU-32's "agent-generated dynamic follow-ups" stretch becomes impossible without amending this. If the TL wants dynamic chips, the amendment is bounded — a `suggestion.free.v1` action whose single argument is a `max_length`-bounded string that is passed to the turn **as user text and nothing else** — and it should be decided now rather than discovered in GGU-32. |
| **OD-2** | A2A turn vs. a REST `POST /v1/surface-actions`. | TL | **A2A turn** (§3.2). Reconsider only if an action ever needs to answer synchronously with something that is not a stream of surfaces — and that action would be `mutating`, which OD-4/AC-9 forbid outright. |
| **OD-3** | Should the backend verify an action came from a surface it actually rendered? | TL | **No — validation is by declaration, not by provenance.** A registered action with valid arguments is valid whoever sends it, exactly as `?view=` is. Provenance checking needs a server-side store of rendered surfaces per turn — the "ticket session" 0018 OD-1 rejected — and buys nothing while no action mutates. **Revisit the day one does**, together with OD-4 and OD-5. |
| **OD-4** | Audit every action, or only the ones that declare it? | TL | **Only declared** (§5). Alternative considered: audit all, on the argument that UI-expressed intent is inherently audit-worthy. Rejected for now because `/v1/me/audit-events` is a demonstration surface for identity events and taps would bury them; retention would carry traffic, not decisions. Reverse this if compliance review wants a complete interaction trail — one line, `audited=True` as the default. |
| **OD-5** | Idempotency for a retried action. | TL | **None, deliberately.** Nothing in scope mutates, so a replay costs a duplicate turn and nothing else. **The rule that must survive this decision:** the first mutating action needs an idempotency key *and* an ADR amendment, and AC-9 makes that physically unavoidable rather than a thing a reviewer must remember. Do not add `Idempotency-Key` to `POST /` speculatively — it is a REST header on a JSON-RPC surface, and A2A's own `messageId` is the natural carrier if one is ever needed. |
| **OD-6** | **ADR-J D-6 requires a recorded decision to extend the JSON-RPC surface.** Approving this spec means adding **ADR-J D-7** — *"the A2A surface accepts one non-text part kind, `data`, carrying a registered action id and bounded scalar arguments; it accepts no other extension."* | TL | **Add D-7 to ADR-J in the implementing PR**, drafted from §3.2. Without it the implementation contradicts an accepted ADR, and the `backend-reviewer` agent should block on that. If the TL prefers, this becomes a short ADR-L instead — the content is the same and the choice is presentational. |
| **OD-7** | Is a drill *really* not an option? `attribution.waterfall.v1` could take a bounded `focus` option and re-render zoomed, costing nothing. | TL | **It is an action** — but only because GGU-31's ACs demand agent recomposition, narration, a back path and a leaf case, which is a turn. **If the TL scopes GGU-31 down to "the same chart, focused", the correct answer is a `focus` option and this whole spec is unnecessary for it** (GGU-32 would then also need nothing, since a chip can be plain `text`). That is a legitimate outcome and cheaper; it is written here so the decision is made on purpose rather than by momentum. |
| **OD-8** | Where does `app/actions/` sit in the layering? | TL — **decided, flagged for review** | A framework-free package, peer of `presentation/`. `presentation` → `actions` is pure-to-pure (a projection imports the declaration to publish it); `services` → `actions` is dispatch. Putting the registry inside `presentation/` would make a pure render package own turn dispatch; putting it inside `agent/` would make `presentation` depend on `agent`. Needs `03-backend-layers.md` updated and the architecture rule's dependency direction checked in the implementing PR. |

## 9. Rollout & observability

- **Feature flag `surface.actions`**, default **off** until the client can send a
  `data` part. Off ⇒ `-32601`, and every existing A2A behaviour byte-identical
  (AC-13). It turns on with GGU-31/GGU-32, not before.
- **No migration**, no data backfill, nothing persisted.
- **Metrics:** `surface.action.accepted{action}`, `surface.action.rejected{action}`
  — id only, never arguments. One structured log line per dispatch with subject
  fingerprinting as the existing audit path does it, and **no prompt text**.
- **Sentry:** a rejected action is expected traffic, not an exception. Only a
  dispatch failure *after* validation is captured, through the existing
  `capture_exception` path in `services/agent_tools.py`.
- **Latency:** validation is a registry lookup plus one pydantic parse — far
  inside the ADR-K budget. The turn that follows is an ordinary agent turn and
  carries the ordinary turn budget (< 1 s to the first streamed surface).
- **Diagrams** updated in the implementing PR, per `.claude/rules/diagrams.md`:
  `05-agent-turn.md` (an action entering the turn), `03-backend-layers.md` (the
  new package, OD-8), `06-response-shaping.md` (a surface declares actions).
- **Adjacent defect, not fixed here:** `RenderIntentService` — the thing that
  enforces ADR-K D-11/D-12 — has **no call site on the agent turn path**
  (`backend/src/app/services/render_intent_service.py`; its docstring names
  GGU-47, which does not call it). Intents emitted by tools are today only
  pattern-checked. This spec relies on that enforcement being real, so it should
  be a ticket of its own before `surface.actions` is switched on.
