# finance-google-a2ui

An open-source reference application for **A2UI**: an AI agent that answers
questions about a portfolio by **composing user interface, not prose**. Ask
"why did my portfolio move this week?" and the agent does not write you a
paragraph — it returns an attribution waterfall, a holdings breakdown and a
tax-lot table, rendered natively by a Flutter client.

Built by [Somnio Software](https://www.somniosoftware.com/) as a showcase with
Google. Apache 2.0.

| | |
|---|---|
| **Try it** | **<https://finance-a2ui.web.app>** |
| Backing API (dev) | <https://finance-a2ui-dev-api-crqogdubva-uc.a.run.app> |
| API documentation | [Swagger UI](https://finance-a2ui-dev-api-crqogdubva-uc.a.run.app/docs) · [`/openapi.json`](https://finance-a2ui-dev-api-crqogdubva-uc.a.run.app/openapi.json) |
| Which build is that? | the site's `/release.json` and the API's `/health` each report the commit they were built from |

> The portfolio data is **simulated** — a seeded, deterministic portfolio. No
> market-data licence, no broker, no live pricing, no way to move money. That
> is deliberate, and it is what makes the demo reproducible. See
> [What is real and what is not](#what-is-real-and-what-is-not).

## The idea in one minute

A normal chatbot answers a finance question with text, and the user is left to
trust a number they cannot inspect. This app does two things differently.

**The agent composes from a fixed catalog.** It does not invent a layout or
emit HTML. It picks a component from a registry the backend publishes — an
attribution waterfall, an allocation summary, a tax-lot table — and fills its
declared options. The catalog is a build-time contract: the client knows every
shape it can be asked to render, so nothing arrives that it cannot draw. The
contract is *generated* from the server's registry, never hand-copied, and the
gate re-renders and diffs it — [`docs/catalog/CONTRACT.md`](docs/catalog/CONTRACT.md).

**The model never computes a number.** Every figure comes from a deterministic
backend tool and arrives as a pre-formatted string the model copies verbatim.
The LLM chooses *what to show*; arithmetic belongs to code that can be tested.
We call it the numbers-from-tools invariant, and it is enforced by tests rather
than by prompt wording: the client has no `NumberFormat`, no `dart:math` and no
`DateTime.now()` anywhere in `lib/`, and an architecture test fails on the
mechanism.

The backend also shapes the payload. The client performs **zero
transformation**: it binds what it receives. Adding a chart is one new module
on the server, not a change on both sides.
[ADR-K](docs/adr/ADR-K-response-shaping.md) explains why, and why we declined
GraphQL.

## Quick start

You need **Docker**, and nothing else — no API key, no cloud account, no
Google project.

```bash
git clone https://github.com/somnio-projects/finance-google-a2ui.git
cd finance-google-a2ui
cp backend/env.example backend/.env     # once per clone; .env is never committed

APP_RELEASE="local+$(git rev-parse --short HEAD)" docker compose up --build
```

One project, `finance-a2ui`, three services, **no profiles**:

| Service | Where | What it is |
|---|---|---|
| Web client | <http://localhost:3001> | the A2UI client — the thing this repository is about |
| API | <http://localhost:8000> | FastAPI, migrations already applied |
| PostgreSQL | `localhost:5432` | `app` / `app`, local only |

Sign in with **`demo@somnio.dev`** and any password. The local stack has no
Firebase, so the Google button says it is not configured rather than
pretending, and the e-mail path is answered by the backend's preview sign-in.
The demo account is provisioned at boot.

Want only the API? Name the services — `docker compose up --build db backend`.
That skips the Flutter build entirely, and needs no profile to exist.

**Why `APP_RELEASE`?** `GET /health` reports it verbatim, and it is the only
thing that says *which build answered*. Without it both halves of the stack
report the useless string `local`. With it, the API's `/health` and the
client's `/release.json` report the same `local+<sha>`, so a screenshot can be
traced back to a commit.

### Useful URLs, once it is up

| Check | URL |
|---|---|
| Interactive API documentation (Swagger UI) | <http://localhost:8000/docs> |
| OpenAPI document | <http://localhost:8000/openapi.json> |
| Liveness, with the build identity | <http://localhost:8000/health> |
| Readiness, including the database | <http://localhost:8000/readyz> |
| The agent card — public, no token | <http://localhost:8000/.well-known/agent-card.json> |
| The client's build identity | <http://localhost:3001/release.json> |

### Getting a token

Every route except the health probes and the agent card needs a bearer token.
With the default `AUTH_PROVIDER=jwt` you can mint one locally:

```bash
cd backend && make token SUBJECT=alice
```

It prints the raw JWT and nothing else, so it composes:

```bash
TOKEN=$(cd backend && make -s token SUBJECT=alice)
curl -H "Authorization: Bearer $TOKEN" http://localhost:8000/v1/views
```

It reads `AUTH_JWT_SECRET` from `backend/.env`; without it the command says so
and exits 1.

### Giving yourself a portfolio

Portfolios are **per owner**, keyed on the verified e-mail claim in the token —
never on anything the request body says. Seed one, or several, with a
re-runnable job:

```bash
cd backend && make seed OWNERS="alice@example.com bob@example.com"
cd backend && make seed OWNERS="alice@example.com" RESET=1   # re-seed from scratch
```

An owner who already has a portfolio is skipped unless you pass `RESET=1`. The
job normalises and de-duplicates the addresses, and never logs them.

### Running the client outside Docker

```bash
cd frontend/app
flutter run -d chrome --dart-define=BACKEND_BASE_URL=http://localhost:8000
```

The Flutter SDK is pinned to **3.47.5** in `frontend/.fvmrc` and nowhere else;
`cd frontend && make gate` proves the SDK on your `PATH` before doing anything
else. No key or secret is ever passed to the client — the Gemini key and every
service credential live on the backend only.

### Configuration

All of it is in `backend/env.example`, one documented variable per line. Copy
it to `backend/.env` and edit. `.env` files are git-ignored and never
committed; the tooling actively denies reading them, and a secret scanner runs
over the **full history** on every pull request.

Two variables are worth knowing before you start:

- **`AUTH_PROVIDER`** — `jwt` for local development and service tokens, or
  `oidc` to verify real ID tokens from Firebase, Google or any other issuer
  through its JWKS endpoint. Switching is a configuration change, not a code
  change.
- **`GEMINI_API_KEY`** — optional. Leave it unset and the agent uses a
  deterministic **scripted** client that needs no network: the demo's
  questions, the curated chips and a tapped bar replay their tool calls with a
  server-written sentence, and anything else answers that no provider is
  configured. Set it and the same code path calls Gemini. The test suite uses a
  null client that records what it was sent.

## What is real and what is not

Measured on 2026-09-22 against the deployed URLs at the top of this file: both
answered `0.1.0+44968fd`, the head of `develop`.

| Part | State |
|---|---|
| **Backend service** — FastAPI, PostgreSQL, layered, 100 % branch coverage | **Real**, and deployed |
| **Web client** — `frontend/`: Flutter, Bloc, go_router, 100 % line coverage per file | **Real**, and deployed to Firebase Hosting |
| **A2A transport** — JSON-RPC `message/stream` over SSE at the service root, plus a public agent card | **Real** |
| **Agent host** — tool registry, turn loop, Gemini | **Real.** With `GEMINI_API_KEY` set it calls Gemini; unset, it falls back to a deterministic scripted client that needs no network |
| **Authentication** — bearer tokens, pluggable `jwt` / `oidc` (Firebase, Google, any SSO) | **Real** |
| **Presentation layer** — versioned projections, `GET /v1/views` catalog, generated contract | **Real** |
| **Infrastructure** — Terraform on Google Cloud: private VPC, Cloud SQL, Secret Manager, Cloud Run, Workload Identity Federation | **Real**, applied |
| **Delivery** — `backend-cd` to Cloud Run, `frontend-cd` to Firebase Hosting | **Real, and both have run** — the deployed builds above are their output. Both are buttons: merging deploys nothing |
| **Market data and prices** | **Simulated.** A seeded, deterministic portfolio |
| **Balances, holdings, tax lots** | **Simulated** |
| **Order execution** | **Does not exist, and never will here** |

**There is no market-data licence and no broker relationship behind this
repository, and there is no live pricing.** The portfolio is generated from a
fixed seed, so every run produces the same figures — which is what makes the
demo reproducible and the tests meaningful. Nothing here is investment advice,
and nothing here can move money.

Two caveats worth stating rather than rounding away. The API above is the
**dev** environment and neither URL carries an uptime commitment. And the gaps
we know about and have not closed — no static security analysis over Dart, no
CVE scan of the Dart dependency graph — are listed with their owners in
[`docs/compliance/VULNERABILITY_MANAGEMENT.md`](docs/compliance/VULNERABILITY_MANAGEMENT.md).

## How the repository is laid out

| Path | What | Start at |
|---|---|---|
| `backend/` | FastAPI · Python 3.14 · PostgreSQL · uv — the API, the presentation layer and the agent host | [`backend/README.md`](backend/README.md) |
| `frontend/` | The A2UI client — a Flutter pub workspace (`app/` plus pure-Dart packages, one of them the chart geometry) | [`frontend/README.md`](frontend/README.md) |
| `infra/` | Terraform for the Google Cloud topology | [`infra/README.md`](infra/README.md) |
| `specs/` | One spec per feature, written before the code | [`specs/README.md`](specs/README.md) |
| `docs/adr/` | Architecture decisions, each with its rulings and what was rejected | [`docs/adr/README.md`](docs/adr/README.md) |
| `docs/diagrams/` | Mermaid diagrams — one question each | [`docs/diagrams/README.md`](docs/diagrams/README.md) |
| `docs/catalog/` | The **generated** frozen component contract | [`docs/catalog/CONTRACT.md`](docs/catalog/CONTRACT.md) |
| `docs/compliance/` | SOC 2 / ISO 27001 policies and evidence | [`docs/compliance/README.md`](docs/compliance/README.md) |
| `docs/manual/` | The **user manual** for the app, English and Spanish, with screenshots — written for a first-time viewer, not a developer | [`docs/manual/README.md`](docs/manual/README.md) |
| `scripts/` | Repository-wide gates: spelling, shell lint, gate pairs, the manual-run check | — |

## Verify it

A change is not done here until both of these are green:

```bash
pre-commit install && pre-commit install --hook-type pre-push   # once per clone

cd backend  && make gate
cd frontend && make gate
```

**`cd backend && make gate`** runs, in order: `ruff` lint and format,
`basedpyright` in strict mode, a 150-line-per-file budget, a
re-render-and-diff of the generated catalog artefacts, an audit of every
OpenAPI operation against what its route can really answer, a code-smell suite
(complexity, dead code, docstring coverage, dependency hygiene, duplication,
typos), the test suite at **100 % branch coverage**, and a dependency CVE
audit.

**`cd frontend && make gate`** opens with a toolchain preflight — a Dart below
the pin reads as a red branch when it is a red laptop — then formatting,
analysis with infos fatal, the file budget, a check that the generated
component manifest is current, every suite, and **100 % line coverage per
file**.

[`.claude/ship-gate.json`](.claude/ship-gate.json) is the machine-readable
Definition of Done, in four parts (`py.*`, `infra.*`, `repo.*`, `frontend.*`).
A gate command whose string has drifted from the workflow that runs it fails
`scripts/check_gate_pairs.sh`, so the gate, the hooks and CI cannot disagree by
accident.

## Where to read next

**Architecture and decisions**

- **[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)** — how the system is put together and why, describing what is built rather than what is planned.
- **[docs/adr/README.md](docs/adr/README.md)** — the decisions, including the rejected ones and the reasons. Start with [ADR-K](docs/adr/ADR-K-response-shaping.md) (response shaping), [ADR-J](docs/adr/ADR-J-rest-api-and-a2a-surface.md) (two surfaces) and [ADR-L](docs/adr/ADR-L-client-architecture.md) (the client).
- **[docs/diagrams/README.md](docs/diagrams/README.md)** — the same system as pictures, in Mermaid so they diff in a pull request.

**The API**

- **[Swagger UI](https://finance-a2ui-dev-api-crqogdubva-uc.a.run.app/docs)** — against the dev API, or `http://localhost:8000/docs` for your own stack.
- **[`/openapi.json`](https://finance-a2ui-dev-api-crqogdubva-uc.a.run.app/openapi.json)** — complete enough that a generator produces a usable client with no hand-editing, and a gate says so.
- **[backend/docs/ENDPOINTS.md](backend/docs/ENDPOINTS.md)** — every route in one table, **generated** from the OpenAPI document.
- **[docs/catalog/CONTRACT.md](docs/catalog/CONTRACT.md)** — the frozen component contract the designer and the client both bind to.

**Process, security and contributing**

- **[specs/README.md](specs/README.md)** — one spec per feature, written before the code.
- **[docs/DEV_HARNESS.md](docs/DEV_HARNESS.md)** — how this repository is built with Claude Code, which is itself part of the showcase.
- **[backend/docs/SECURITY.md](backend/docs/SECURITY.md)** — the controls, mapped to SOC 2 and ISO 27001.
- **[SECURITY.md](SECURITY.md)** — how to report a vulnerability. Please do not open a public issue for one.
- **[CONTRIBUTING.md](CONTRIBUTING.md)** — how to propose a change. Every pull request targets `develop`.

## Licence

Apache 2.0 — see [LICENSE](LICENSE) and [NOTICE](NOTICE). No third-party source
is vendored: the client in `frontend/` was written from scratch and derives
nothing from Google's `restaurant_finder` sample. An earlier second client did
derive from it; it was retired on 2026-09-22 and the attribution retired with
it ([`specs/repo/0002`](specs/repo/0002-retire-the-client-flutter-app.md)).
