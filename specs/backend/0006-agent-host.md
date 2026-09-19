# 0006 — Agent host: Gemini adapter, tool registry and turn loop

- **Area:** backend
- **Status:** Implemented
- **Ticket:** GGU-47 · **Related specs / ADRs:** 0001, 0003, ADR-D, ADR-E, ADR-G, ADR-J, ADR-K
- **Owner:** Lautaro Bertuzzi · **Date:** 2026-09-19

## 1. Problem

The showcase exists to demonstrate an agent that answers a portfolio question
by composing UI instead of prose. Today the backend has a portfolio (spec
0003) and an HTTP surface (spec 0001), but **nothing that talks to a model**:
no client, no tool contract, no turn loop. GGU-3 (A2A streaming surface) and
GGU-46 (sessions) both need to call "run one turn" and cannot start until that
call exists, and Epic 1's four tool tickets (GGU-36/37/38/39) have nowhere to
register what they build.

The two hard constraints this ticket must not break are already written down:
the **product invariant** that the LLM never computes a financial figure
(ADR-E, root `CLAUDE.md`), and the **secret rule** that a provider credential
lives in `Settings` as a `SecretStr` and is read only by the adapter that
consumes it (ADR-G, `.claude/rules/backend/security.md`). A naive agent host
breaks both: it hands the model raw numbers to format, and it reads the API
key from the environment wherever it is convenient.

## 2. Scope

**In:**

- A `ModelClient` Protocol in `app/core/protocols.py` plus the framework-free
  conversation contract it speaks (`app/core/model.py`).
- A Gemini adapter under `app/infra/model/` over the already-vendored `httpx`,
  with a bounded timeout, bounded retries and total failure translation into
  `DependencyUnavailableError`.
- A `NullModelClient` — deterministic, no network, scripted — selected
  automatically when no key is configured, exactly as `NullErrorReporter` is.
- A single display-formatting module (`app/core/display.py`) so `Decimal` →
  string happens in one place (ADR-E D-2).
- A tool contract and registry under `app/agent/`, filled by **local
  registration**: a tool module registers itself and the package discovers it.
- **One reference tool** (`get_holdings_summary`) proving the seam end to end.
- The turn loop as `app/services/agent_service.py`, with a documented bound on
  tool iterations per turn.
- One structured log line and one metric per turn; failures through the
  injected `ErrorReporter`.
- Wiring in `bootstrap.py` / `api/container.py` / `api/deps.py`, and the new
  settings documented in `backend/env.example`.

**Out:**

- **Sessions and history persistence** — GGU-46. `run_turn` takes the history
  as an argument and returns a result; no session module is imported.
- **Streaming and the A2A surface** — GGU-3 / ADR-D. This ticket exposes **no
  HTTP route**: `api/v1/`, `api/router.py` and the OpenAPI document are
  unchanged.
- **The presentation layer and projection registry** — GGU-49 / ADR-K. This
  spec defines only the *minimal* render-intent shape it produces (§3) and
  performs **no validation of it against the projection registry**; ADR-K D-12
  validation lands with that registry.
- The remaining deterministic tools (GGU-36/37/38/39) — they arrive as new
  modules under `app/agent/tools/` and edit nothing.
- Prompt engineering beyond the system prompt that states the invariants, and
  the registry-generated catalog fragments of ADR-K D-14 (GGU-14).

## 3. API contract

**This ticket exposes no HTTP surface.** What follows is the **module**
contract that GGU-3, GGU-46 and Epic 1 code against.

### 3.1 The model contract (`app/core/model.py`, `app/core/protocols.py`)

| Type | Shape |
|---|---|
| `MessageRole` | `user` · `assistant` · `tool` |
| `ToolSpec` | `name` (`^[a-z][a-z0-9_]{2,47}$`), `description` (1–512), `parameters` — a JSON Schema object |
| `ToolCall` | `call_id`, `name`, `arguments: Mapping[str, object]` |
| `ModelMessage` | `role`, `text`, `tool_calls: tuple[ToolCall, ...]`, `tool_name`, `tool_call_id`, `tool_result: Mapping[str, object] \| None` |
| `ModelReply` | `text`, `tool_calls: tuple[ToolCall, ...]` |

```python
class ModelClient(Protocol):
    @property
    def name(self) -> str: ...
    async def generate(
        self,
        *,
        system: str,
        messages: Sequence[ModelMessage],
        tools: Sequence[ToolSpec],
    ) -> ModelReply: ...
```

`generate` is **stateless**: the whole conversation is passed on every call.
That is what lets GGU-46 own history without this layer knowing it exists.

### 3.2 The tool-call protocol (`app/agent/`)

```python
class Tool(Protocol):
    @property
    def name(self) -> str: ...
    @property
    def description(self) -> str: ...
    @property
    def parameters(self) -> Mapping[str, object]: ...   # JSON Schema
    async def run(
        self, arguments: Mapping[str, object], context: ToolContext
    ) -> ToolOutcome: ...
```

- `ToolContext` carries `subject` and a `PortfolioProvider` — everything a
  tool may reach. A tool never opens a session, never touches SQLAlchemy and
  never reads `Settings`.
- `ToolOutcome` is `{data: Mapping[str, object], render: RenderIntent | None}`.
  `data` is the JSON-serialisable payload fed back to the model; every number
  in it is a pre-formatted `*Display` string (ADR-E D-3, ADR-K D-5).
- **Registration is local** (ADR-K D-7): a tool module ends with
  `register(MyTool())`. `load_tools()` imports every module in
  `app.agent.tools` via `pkgutil`, so **adding a tool edits no shared file** —
  no central list, no enum, no `if/elif` chain.
- Registering a duplicate name raises `ConfigurationError` at startup.
  `registry.get(name)` returns `None` for an unknown name — a hallucinated
  tool is a turn-level event, not a crash.

**Render intent (minimal, consumed only).** Per ADR-K D-11 a turn may carry
render intents. This spec defines only what it emits:

```python
class RenderIntent(BaseModel):   # frozen
    view: str      # "<component>.<variant>.v<N>", e.g. "holdings.allocation.v1"
    options: Mapping[str, object]
```

The agent host **produces** these and returns them in `TurnResult`. It does
not render them, does not resolve them and does not validate them against the
projection registry — GGU-49 owns that, and ADR-K D-12 rejection/fallback
lands with it (OD-2).

### 3.3 The turn loop (`app/services/agent_service.py`)

```python
class AgentService:
    def __init__(self, *, model, tools, reporter, clock, max_iterations) -> None: ...
    async def run_turn(
        self, *, prompt: str, history: Sequence[ModelMessage], context: ToolContext
    ) -> TurnResult: ...
```

`TurnResult` = `{message, render_intents, tool_calls, iterations, truncated}`.

One turn is:

1. `messages = [*history, user(prompt)]`.
2. Call `model.generate(system=SYSTEM_PROMPT, messages, tools=registry.specs())`.
3. No tool calls → the reply text is the answer; return.
4. Tool calls → append the assistant message, execute each call, append one
   `role=tool` message per call carrying the tool's `data`, then go to 2.
5. Stop after `AGENT_MAX_TOOL_ITERATIONS` model calls (default **4**).

**The iteration bound.** `max_iterations` counts **model calls**, not tools: a
reply asking for three tools is one iteration. When the bound is reached with
the model still asking for tools, the loop stops, `truncated=True`, and the
turn answers with a fixed safe message (`ITERATION_LIMIT_MESSAGE`) rather than
a half-finished model sentence. Four iterations is one plan + up to three
rounds of correction — enough for every flow in the demo and a hard ceiling on
cost and latency for a runaway model.

### 3.4 Failure modes

| Failure | Where it is translated | What the caller sees |
|---|---|---|
| Provider timeout / connection error | `GeminiModelClient` | `DependencyUnavailableError` after `max_attempts` |
| Retryable HTTP status (408/429/500/502/503/504) | `GeminiModelClient` | retried, then `DependencyUnavailableError` |
| Non-retryable HTTP status (401/403/400…) | `GeminiModelClient` | `DependencyUnavailableError` **immediately**, no retry |
| Body is not JSON, or not a Gemini reply | `GeminiModelClient` | `DependencyUnavailableError` |
| Model asks for an unregistered tool | `AgentService` | `{"error": "unknown-tool"}` fed back; the turn continues |
| A tool raises anything | `AgentService` | `{"error": "tool-failed"}` fed back, exception to `ErrorReporter`; the turn continues |
| Iteration bound reached | `AgentService` | `TurnResult(truncated=True)` with the fixed message |

Every `DependencyUnavailableError` from the adapter carries the **same fixed
detail** (`"model provider unavailable"`). No provider text, no status line, no
URL, no key fragment ever reaches the message, the log or the problem
document; the original exception is kept only as `__cause__`.

## 4. Data model & migration

**None.** No table, no column, no Alembic revision. The agent host is
stateless; history is an argument and the portfolio lives in memory (ADR-F).

New modules:

| Module | Holds |
|---|---|
| `core/model.py` | `MessageRole`, `ToolSpec`, `ToolCall`, `ModelMessage`, `ModelReply` |
| `core/display.py` | `money_display`, `signed_money_display`, `quantity_display`, `percent_display` — the single `Decimal` → string boundary (ADR-E D-2) |
| `infra/model/payload.py` | Gemini wire mapping: `to_request`, `from_response` |
| `infra/model/gemini_client.py` | `GeminiModelClient` — key, timeout, retries, translation |
| `infra/model/null_client.py` | `NullModelClient`, `RecordedCall` |
| `infra/model/factory.py` | `build_model_client(settings)` |
| `agent/contracts.py` | `Tool`, `ToolContext`, `ToolOutcome`, `RenderIntent`, `TurnResult` |
| `agent/registry.py` | `ToolRegistry`, `REGISTRY`, `register`, `load_tools` |
| `agent/prompt.py` | `SYSTEM_PROMPT` |
| `agent/tools/holdings_summary.py` | the reference tool |
| `services/agent_service.py` | the turn loop |

New settings (documented in `env.example`):

| Variable | Default | Bound |
|---|---|---|
| `GEMINI_API_KEY` | unset → `NullModelClient` | `SecretStr` |
| `GEMINI_MODEL` | `gemini-3.8-flash` (ADR-D D-4) | 1–64 chars |
| `GEMINI_BASE_URL` | `https://generativelanguage.googleapis.com/v1beta` | 1–255 |
| `GEMINI_TIMEOUT_SECONDS` | `20.0` | `ge=1.0, le=120.0` |
| `GEMINI_MAX_ATTEMPTS` | `3` | `ge=1, le=5` |
| `AGENT_MAX_TOOL_ITERATIONS` | `4` | `ge=1, le=10` |

**Layering.** `app/agent/` is an inner layer beside `app/domain/`: it may
import stdlib, pydantic, `app.core` and `app.domain`, and nothing else in
`app`. `app/services/agent_service.py` imports `app.agent` and `app.core`; it
imports no FastAPI and no SQLAlchemy.

## 5. Security notes

- **Credential** (CC6.1, CC6.7 · A.5.33, A.8.24). `GEMINI_API_KEY` is a
  `SecretStr` on `Settings`. `.get_secret_value()` appears **once**, inside
  `GeminiModelClient._headers`. The key is never logged, never placed in a
  URL or query string, never attached to an error, and never handed to any
  other layer. AC-2 asserts this over the parsed source, not by inspection.
- **Error masking** (CC7.4 · A.8.9). Provider text never leaves the adapter
  (§3.4). `DependencyUnavailableError` renders as the existing RFC 9457
  `503` document with a fixed detail.
- **Logging & PII** (CC7.2 · A.8.15). The per-turn log line carries `model`,
  `outcome`, `duration_ms`, `tool_calls`, `iterations`, `truncated` — and
  nothing else. **No prompt text, no reply text, no tool arguments, no tool
  results, no subject, no email.** A reported wrong answer is reproduced from
  the portfolio's fixed `as_of` (spec 0003), not from a logged conversation,
  which is why the conversation is never written down here.
- **Prompt injection.** Model output is data: a tool name that is not
  registered is refused, tool arguments are validated by a pydantic model with
  `extra="forbid"`, and a tool reaches only its `ToolContext`. The model
  cannot name a subject, widen a scope or reach a repository.
- **No audit event.** A turn is not an identity action, so nothing is written
  to `audit_events`. When GGU-3 exposes the turn over HTTP, that route carries
  the usual `PrincipalDep`; authorization stays where it is today.
- **Cost/DoS bound.** The iteration bound (§3.3), the HTTP timeout and the
  attempt cap are the three ceilings on what one turn can spend.

## 6. Acceptance criteria

1. **AC-1** — `ModelClient` exists in `app/core/protocols.py` and both
   `GeminiModelClient` and `NullModelClient` satisfy it structurally.
2. **AC-2** — The Gemini API key is a `SecretStr` read from `Settings`, and
   `get_secret_value()` appears in exactly one module of `src/app`
   (`infra/model/gemini_client.py`) for it; no other layer references
   `gemini_api_key`.
3. **AC-3** — Every provider failure — connection error, timeout, retryable
   status, non-retryable status, non-JSON body, malformed reply — raises
   `DependencyUnavailableError` whose message is the fixed
   `"model provider unavailable"` and contains no provider text.
4. **AC-4** — The adapter retries retryable failures up to
   `GEMINI_MAX_ATTEMPTS` and does **not** retry a non-retryable status; the
   HTTP timeout is `GEMINI_TIMEOUT_SECONDS`.
5. **AC-5** — `build_model_client` returns `NullModelClient` when
   `GEMINI_API_KEY` is unset and `GeminiModelClient` when it is set; no call
   site branches on configuration.
6. **AC-6** — `NullModelClient` is deterministic and performs no I/O: a
   scripted sequence of replies is returned in order, the last one repeating.
7. **AC-7** — A tool registers itself from its own module; `load_tools()`
   discovers every module in `app.agent.tools` without a shared list, enum or
   `if/elif`. Registering a duplicate name raises `ConfigurationError`.
8. **AC-8** — `get_holdings_summary` returns only pre-formatted `*Display`
   strings for every figure; the reference tool computes the totals and the
   weights server-side from `Decimal`, and the payload contains no raw number
   the model could re-format.
9. **AC-9** — `run_turn` returns the model's answer when the model asks for no
   tool; executes the requested tools and feeds their results back when it
   does; and handles several tool calls in one reply.
10. **AC-10** — `run_turn` stops after `AGENT_MAX_TOOL_ITERATIONS` model calls,
    returns `truncated=True` with the fixed `ITERATION_LIMIT_MESSAGE`, and
    calls the model no more than that many times.
11. **AC-11** — A tool that raises does not fail the turn: the exception goes
    to `ErrorReporter.capture_exception`, `{"error": "tool-failed"}` is fed
    back to the model, and the turn produces an answer. An unregistered tool
    name yields `{"error": "unknown-tool"}` the same way.
12. **AC-12** — A `DependencyUnavailableError` from the model propagates out of
    `run_turn` after being reported to `ErrorReporter`.
13. **AC-13** — Exactly one metric (`agent.turn`, tagged `model` and
    `outcome`) and exactly one log line (`agent.turn`) are emitted per turn,
    on both the success and the failure path, and neither carries prompt text,
    tool arguments, tool results or the subject.
14. **AC-14** — `app/agent/` imports nothing from `api`, `services`,
    `repositories`, `models`, `schemas`, `infra`, `auth` or `bootstrap`, and
    `services/agent_service.py` imports neither FastAPI nor SQLAlchemy nor any
    session module.
15. **AC-15** — `make gate` is green: ruff, basedpyright strict, the 150-line
    budget, `make quality` and pytest at 100 % branch coverage.

## 7. Test plan

| AC | Unit test(s) | Integration test(s) |
|---|---|---|
| AC-1 | `tests/unit/infra/model/test_factory.py::test_build_model_client_*` (assigned to `ModelClient`) | — |
| AC-2 | `tests/unit/agent/test_package_boundaries.py::test_the_api_key_is_read_in_exactly_one_module` | — |
| AC-3 | `tests/unit/infra/model/test_gemini_client.py::test_generate_*_raises_dependency_unavailable` (parametrized over the failure modes) | — |
| AC-4 | `test_gemini_client.py::test_generate_retries_a_retryable_status_until_the_attempt_cap`, `::test_generate_does_not_retry_a_non_retryable_status`, `::test_client_uses_the_configured_timeout` | — |
| AC-5 | `tests/unit/infra/model/test_factory.py` | — |
| AC-6 | `tests/unit/infra/model/test_null_client.py` | — |
| AC-7 | `tests/unit/agent/test_registry.py` | — |
| AC-8 | `tests/unit/agent/tools/test_holdings_summary.py`, `tests/unit/core/test_display.py` | — |
| AC-9 | `tests/unit/services/test_agent_service.py::test_run_turn_without_tool_calls_*`, `::test_run_turn_executes_a_single_tool_call_*`, `::test_run_turn_executes_several_tool_calls_*` | — |
| AC-10 | `test_agent_service.py::test_run_turn_stops_at_the_iteration_bound_*` | — |
| AC-11 | `test_agent_service.py::test_run_turn_reports_a_failing_tool_*`, `::test_run_turn_answers_unknown_tool_*` | — |
| AC-12 | `test_agent_service.py::test_run_turn_reports_and_reraises_a_model_failure` | — |
| AC-13 | `test_agent_service.py::test_run_turn_records_one_metric_*`, `::test_turn_log_carries_no_prompt_or_subject` | — |
| AC-14 | `tests/unit/agent/test_package_boundaries.py` | — |
| AC-15 | the gate itself | — |

Unit only: the agent host touches no database and opens no socket, so there is
nothing an integration test could add that the fakes do not already prove.
The Gemini adapter is driven through an injected `httpx.AsyncClient` over
`httpx.MockTransport` — real `httpx` parsing, no network.

**Mutation checks required (auth / rate limit / error masking): yes** — for
error masking. Removing the `except` that translates provider failures in
`GeminiModelClient` must turn the AC-3 tests red.

## 8. Open decisions

| # | Question | Owner | Default if unresolved |
|---|---|---|---|
| OD-1 | Gemini via the official `google-genai` SDK or over the already-vendored `httpx`? | TL | **`httpx`** — resolved here: no new dependency, no `pip-audit`/`deptry` surface, and the adapter is the same shape as `JwksKeyResolver`, which is the pattern the tree already proves. Swapping to the SDK later is one module. |
| OD-2 | Who validates a render intent against the projection registry? | TL | **GGU-49** — this ticket emits `{view, options}` and validates nothing; ADR-K D-12 rejection + fallback lands with the registry. |
| OD-3 | Which model id is the default? | TL | **`gemini-3.8-flash`** — the only model pin recorded in the repo (ADR-D D-4). Overridable with `GEMINI_MODEL`; nothing in the code depends on the id. |
| OD-4 | Should the turn loop stream partial surfaces? | TL | **No** — ADR-D/ADR-K D-19 put streaming in GGU-3. `run_turn` is the unit GGU-3 wraps. |
| OD-5 | Where does `Decimal` → display formatting live, given `app/presentation/` is being created in parallel? | TL | **`app/core/display.py`** — ADR-E D-2 demands *one* formatting module; `core` is the only place both `app/agent` and `app/presentation` may import. The presentation layer reuses it rather than adding a second. |
| OD-6 | Do tool arguments and results belong in telemetry when a demo answer is wrong? | TL | **No** — §5. Reproduction comes from the fixed `as_of`; a conversation log is a PII surface the showcase does not need. |
| OD-7 | The Gemini wire mapping has never met the real API. | TL — **carried** | It cannot be proven here: there is no route (GGU-3) and no key in this environment, so every test runs against stubs we wrote ourselves. `payload.py` is 100 % covered against *our* assumption of the format, which is not the same as being correct. **GGU-3 carries the first live `generateContent` round trip** and must treat a mapping fix as expected, not as a regression. |
| OD-8 | A turn has no wall-clock deadline. | TL — **deferred to GGU-3** | The ceilings multiply: 4 iterations × 3 attempts × 20 s ≈ 240 s worst case. `AGENT_MAX_TOOL_ITERATIONS` bounds cost, not latency. Once a route exists that worst case ties up a worker, so the deadline belongs with the transport that owns the request, not with the loop. |
| OD-9 | Retries have no backoff and ignore `Retry-After`. | TL — **deferred** | Three immediate re-POSTs on a 429 turn a soft rate limit into a hard one. Bounded, so not a storm; worth fixing when the p95 budget in ADR-K is measured rather than asserted. |
| OD-10 | The adapter opens a new `httpx.AsyncClient` per call. | TL — **deferred** | A TLS handshake per model call, up to four per turn. Cheap to fix by building it once in the factory; it only shows up against the latency budget, which needs a route first. |
| OD-11 | A hallucinated tool argument reaches Sentry. | TL — **the spec is what should change** | §3.4 says "a tool raises anything → report", and a `pydantic.ValidationError` from a bad argument is expected model behaviour the loop already handles. It should be logged, not reported. Changed with the first tool that does I/O, when the distinction starts to matter. |
| OD-12 | Tool `call_id`s are unique within a reply, not across a turn. | TL — **deferred to GGU-46/GGU-3** | Two iterations that both call the same tool at part 0 produce the same id. Harmless today (Gemini matches `functionResponse` by name) but `ModelMessage.tool_call_id` is the contract those tickets will persist and correlate on, so it is fixed there, with the tests that need it. |

## 9. Rollout & observability

- **No feature flag.** The agent host has no route to gate; GGU-3 gates the
  A2A surface when it exposes one.
- **No migration**, so no ordering concern.
- **Metric:** `agent.turn`, tags `{model, outcome}` where `outcome` is `ok` or
  `model-unavailable`. **Log:** one `agent.turn` info line per turn with the
  fields listed in §5, plus `agent.tool.failed` (warning, tool name and
  exception *type* only) when a tool raises.
- **Sentry expectation:** a failing tool and an unavailable provider both
  arrive as captured exceptions; a truncated turn does not (it is a bound
  working, not an error) and is visible through the `truncated` log field.
- **Startup:** with no `GEMINI_API_KEY` the service starts on
  `NullModelClient` and answers deterministically — the demo never fails to
  boot because a key is missing.
