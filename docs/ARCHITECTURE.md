# Architecture

How this system is put together, and why. **It describes what is built, not
what is planned** — anything not built is marked as such, in the same words the
[README](../README.md) uses. Diagrams live in
[`docs/diagrams/`](diagrams/README.md); the reasoning behind each decision is
in an [ADR](adr/README.md). This document is the map between them.

## The problem it solves

A finance assistant that answers in prose asks the user to trust a number they
cannot inspect, and gives the same flat paragraph whether the answer is one
figure or a hundred. This application answers in **interface**: the agent
composes a view out of a fixed catalog of components and the client renders it
natively.

Two rules make that safe rather than merely clever.

**The model never computes a figure.** Every number comes from a deterministic
backend tool and arrives as a pre-formatted string the model copies verbatim.
The LLM decides *what to show*; arithmetic belongs to code with tests. This is
the *numbers-from-tools* invariant, and the tool tests assert that every value
a tool returns is a display string, not a number the model could re-derive.

**The client transforms nothing.** It binds what it receives. The backend
shapes each payload into exactly the structure the widget needs, so adding a
chart is one new server module rather than a coordinated change on both sides.

## The shape of the system

See [01 — system context](diagrams/01-system-context.md) and
[02 — containers](diagrams/02-containers.md).

The Flutter client talks to one backend service, which talks to PostgreSQL, to
Gemini and to an OIDC identity provider. Nothing else is in the trust boundary.

**Two surfaces on one service**, which is
[ADR-J](adr/ADR-J-rest-api-and-a2a-surface.md):

- **`/v1/**` is ours and is strictly RESTful.** Resource nouns, HTTP verbs
  carrying the semantics, RFC 9457 problem documents for every error, and an
  OpenAPI document complete enough to generate a client from.
- **The A2A root is a thin protocol adapter.** A2A — the protocol Google's
  client SDK speaks — is JSON-RPC posted to the service root with an agent card
  at a well-known path. That contradicts the REST rule, so the two live on
  different paths rather than fighting: the adapter translates the envelope and
  delegates to the same services. *(The adapter is not built yet.)*

## Inside the backend

See [03 — backend layers](diagrams/03-backend-layers.md).

Dependencies point inward only, and the rule is enforced by tests that read the
**parsed source**, not by convention:

```
api/v1/        controllers — resolve Depends, call one service, return the DTO
api/deps/      every dependency provider; the only place services are constructed
services/      use cases; never import FastAPI or SQLAlchemy
repositories/  the only code that touches a database session
models/        SQLAlchemy entities
schemas/       pydantic DTOs, frozen
presentation/  projections — pure functions from domain result to payload
agent/         the tool registry and the turn's contracts
domain/        the portfolio aggregate, pure, Decimal only
infra/, auth/  adapters behind Protocols declared in core/
core/          settings, errors, protocols, logging, display — framework-free
bootstrap.py   the single composition root
```

Three constraints do most of the work: **no file over 150 lines**, **100 %
branch coverage**, and **basedpyright in strict mode**. The line budget is the
interesting one — it forces a split by responsibility exactly when a module
starts doing two jobs, which is earlier than anyone would split it voluntarily.

## A request

See [04 — request lifecycle](diagrams/04-request-lifecycle.md).

Every route except `/health` and `/readyz` is authenticated. Middleware runs
outermost-first: request id, security headers, trusted host, CORS, body limit,
rate limit. The controller resolves the caller through one dependency, the
service makes the authorization decision, the repository runs the query, and
any error leaves as a problem document that carries a code and no internals —
no stack trace, no SQL, no library message.

**Authentication is pluggable** ([ADR-B](adr/ADR-B-auth-credential-contract.md)).
`AUTH_PROVIDER=jwt` verifies HS256 tokens for local development and service
callers; `oidc` verifies RS256 signatures against an issuer's JWKS endpoint,
which is how Firebase, Google or any other SSO plugs in. Adding a provider is
one module and one registry entry.

**Identity actions are audited.** Reads of the caller's own identity,
privileged operations and data exports write an `audit_events` row naming the
action and its target. Rows are purged on a retention schedule.

## Sessions and isolation

A conversation session belongs to the authenticated subject, and that is
enforced in the repository rather than the controller: every query filters by
subject. Presenting another subject's session id returns **404**, byte-identical
to a session that does not exist — a 403 would confirm it exists, which is
exactly what the isolation is meant to prevent.

## A turn

See [05 — agent turn](diagrams/05-agent-turn.md).

The turn loop assembles the system prompt and the conversation history, calls
the model, executes whatever tools the model asked for, feeds the results back,
and repeats until the model stops or a bounded number of iterations is reached.
On exhaustion it answers a fixed message rather than half a sentence.

**Tools register from their own module.** Adding one edits no shared file — the
registry discovers it. That seam is what lets several people add tools in
parallel without touching each other's work.

A misbehaving tool never fails the turn: the model receives an error object and
another iteration, and only the exception reaches the error reporter. A tool
the model invented is not reported at all, because that is the model's mistake
rather than a defect.

**The model provider is behind a Protocol.** With no API key configured the
service uses a deterministic null client that needs no network — which is how
the entire test suite runs, and why no call site anywhere branches on whether
Gemini is configured.

## How a payload is shaped

See [06 — response shaping](diagrams/06-response-shaping.md) and
[ADR-K](adr/ADR-K-response-shaping.md).

A **projection** is a pure function from *(domain result, options)* to a DTO,
registered under a versioned id such as `attribution.waterfall.v1`. It performs
no I/O, holds no business rule and never reads a clock.

Elasticity comes from **declared options**, never from a free-form query
language: each projection publishes a bounded, defaulted, documented options
model, and anything undeclared is a 422 rather than a best-effort guess. That
is the whole reason a client-supplied template language was rejected — it is an
injection surface that cannot be documented or covered.

**Two callers, one registry.** The client asks with `?view=<id>`; the agent
emits a render intent `{view, options}` in its tool call. Both resolve through
the same registry and the same validation, so **the model picks a shape, it
never invents one**. If it names something unknown, the request is rejected,
telemetry records it, and the endpoint's default projection is used. When
nobody expresses a preference, a tested per-endpoint rule chooses from the
data.

Registering a projection once publishes it to four consumers: the OpenAPI
document, the `GET /v1/views` catalog, the prompt fragments that teach the
model the catalog, and the A2UI adapter for the client. The prompt fragments
are **generated from the registry**, so what the model believes about the
catalog cannot drift from what the code will actually render.

Several widgets can be requested in one round trip by repeating `?view=`: one
authentication, one session, one domain build, then *N* pure renders.

## Money

See [ADR-E](adr/ADR-E-money-representation.md).

Money is `Decimal` everywhere, never `float`, and a test asserts over the
parsed source that the domain mentions `float` in exactly one module. Rounding
is banker's rounding and happens **only at display**, in one module, so the
same figure cannot be rendered two ways in one answer. The exact value travels
next to the string it produced, so a chart can plot precisely what the label
says.

## What is simulated

The portfolio is generated from a fixed seed when the process starts: holdings,
tax lots, transactions and a 90-day price history. The valuation date is fixed
at first access, so a given question produces the same answer on every run.

**There is no market-data licence and no broker relationship behind this
repository.** Prices are invented, balances are invented, and no order can be
placed. That is not a limitation to be fixed later; it is what makes an
open-source reference application legally and practically shareable, and it is
why the demo is reproducible.

## Deployment

See [08 — infrastructure](diagrams/08-infrastructure.md) and
[09 — delivery pipeline](diagrams/09-delivery-pipeline.md). **Written and
tested; never run** — the cloud project does not exist yet.

Terraform describes the whole topology: a private VPC, Cloud SQL with regional
high availability and point-in-time recovery, Secret Manager with rotation,
Cloud Run behind an HTTPS load balancer with Cloud Armor, log retention and
alerts. The service account holds the narrowest roles that work.

The pipeline builds the image, pushes it by **digest**, creates a revision with
**no traffic** (its startup applies the migrations), waits for that revision to
report ready, shifts traffic, verifies the deployed release identifier, and
**restores the previous revision** if any of that fails. GitHub Actions
authenticates with Workload Identity Federation; there is no long-lived
service-account key anywhere, and a test fails the build if one is ever added.

## How the repository is built

Every feature starts as a **spec** ([`specs/`](../specs/README.md)) with
numbered acceptance criteria, before any code. Decisions that outlive a feature
become **ADRs**. Structural facts become **diagrams**, updated in the same pull
request as the structure they describe. Each iteration appends to a harness log
so the next person can see what changed and why.

This is itself part of the showcase: the repository is developed with Claude
Code, and [`docs/DEV_HARNESS.md`](DEV_HARNESS.md) documents how. Everything the
agent must follow is written down in the repository rather than in a
conversation, which is the only way a second developer's agent reaches the same
decisions.

## Known gaps

Stated here so the code and the documentation agree:

| Gap | Owner |
|---|---|
| The A2A transport — the agent host has no HTTP surface yet | GGU-3 |
| The Flutter client is still Google's upstream sample | Epic 1 |
| The Gemini wire mapping has only been tested against stubs we wrote | GGU-3's first live call |
| The delivery pipeline has never run; no cloud project exists | GGU-29 |
| The catalog gallery and its component documentation | GGU-22 |
