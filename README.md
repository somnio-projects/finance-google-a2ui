# finance-google-a2ui

An open-source reference application for **A2UI**: an AI agent that answers
questions about a portfolio by **composing user interface, not prose**. Ask
"why did my portfolio move this week?" and the agent does not write you a
paragraph — it returns an attribution waterfall, a holdings breakdown and a
tax-lot table, rendered natively by the Flutter client.

Built by [Somnio Software](https://www.somniosoftware.com/) as a showcase with
Google. Apache 2.0.

> **Status: under construction, and this README says which parts are real.**
> The backend is built and tested. The Flutter client is still substantially
> Google's upstream `restaurant_finder` sample and has not been adapted yet.
> There is no end-to-end demo to run today. See
> [What is real and what is not](#what-is-real-and-what-is-not) — we would
> rather you know before you clone than after.

## The idea in one minute

A normal chatbot answers a finance question with text, and the user is left to
trust a number they cannot inspect. This app does two things differently.

**The agent composes from a fixed catalog.** It does not invent a layout or
emit HTML. It picks a component from a registry the backend publishes — an
attribution waterfall, an allocation summary, a tax-lot table — and fills its
declared options. The catalog is a build-time contract: the client knows every
shape it can be asked to render, so nothing arrives that it cannot draw.

**The model never computes a number.** Every figure comes from a deterministic
backend tool and arrives as a pre-formatted string the model copies verbatim.
The LLM chooses *what to show*; arithmetic belongs to code that can be tested.
We call it the numbers-from-tools invariant and it is enforced by tests, not by
prompt wording.

The backend also shapes the payload. The client performs **zero
transformation**: it binds what it receives. Adding a chart is one new module
on the server, not a change on both sides.
[ADR-K](docs/adr/ADR-K-response-shaping.md) explains why, and why we declined
GraphQL.

## What is real and what is not

| Part | State |
|---|---|
| **Backend service** — FastAPI, PostgreSQL, layered, 100 % branch coverage | **Real**, and the substance of this repo today |
| **Authentication** — bearer tokens, pluggable `jwt` / `oidc` (Firebase, Google, any SSO) | **Real** |
| **Conversation sessions**, isolated per authenticated subject | **Real** |
| **Agent host** — Gemini adapter, tool registry, turn loop | **Real**, but not yet reachable over HTTP (needs the A2A transport) |
| **Presentation layer** — versioned projections, `GET /v1/views` catalog | **Real** |
| **Delivery pipeline** — build, publish, deploy, verify, roll back | **Written and tested**, never run: the cloud project does not exist yet |
| **A2A transport** — the JSON-RPC surface the client talks to | **Not built** |
| **Flutter client** | **Upstream Google sample, unmodified.** Not adapted to finance |
| **Market data and prices** | **Simulated.** A seeded, deterministic in-memory portfolio |
| **Balances, holdings, tax lots** | **Simulated** |
| **Order execution** | **Does not exist, and never will here** |

**There is no market-data licence and no broker relationship behind this
repository, and there is no live pricing.** The portfolio is generated from a
fixed seed at startup, so every run produces the same figures — which is what
makes the demo reproducible and the tests meaningful. Nothing here is
investment advice, and nothing here can move money.

## Run the backend

The backend runs on its own today. You need Docker, and nothing else — no API
key, no cloud account, no Google project.

```bash
git clone https://github.com/somnio-projects/finance-google-a2ui.git
cd finance-google-a2ui
cp backend/env.example backend/.env     # once per clone; never committed
docker compose up --build
```

That gives you PostgreSQL and the API on <http://localhost:8000>, with
migrations already applied.

| Check | URL |
|---|---|
| Interactive API documentation | <http://localhost:8000/docs> |
| OpenAPI document | <http://localhost:8000/openapi.json> |
| Liveness | <http://localhost:8000/health> |
| Readiness, including the database | <http://localhost:8000/readyz> |

Every route except the health ones needs a bearer token. With the default
`AUTH_PROVIDER=jwt` you can mint one locally:

```bash
cd backend && make token SUBJECT=alice
```

Then call the API with the header line `Authorization: Bearer <that token>`.

### Configuration

All of it lives in `backend/env.example`, one documented variable per line.
Copy it to `backend/.env` and edit. `.env` files are git-ignored and are never
committed — the repository's tooling actively denies reading them, and a secret
scanner runs over the **full history** in CI.

Two variables are worth knowing before you start:

- `AUTH_PROVIDER` — `jwt` for local development and service tokens, or `oidc`
  to verify real ID tokens from Firebase, Google or any other issuer through
  its JWKS endpoint. Switching is a configuration change, not a code change.
- `GEMINI_API_KEY` — optional. Leave it unset and the agent uses a
  deterministic **scripted** client that needs no network: the demo's three
  questions, the curated chips and a tapped bar replay their tool calls with a
  server-written sentence, and anything else answers that no provider is
  configured (spec `backend/0033`). Set it and the same code path talks to
  Gemini. The test suite uses a null client that records what it was sent.

## Run the Flutter client

**Not yet.** `client_flutter/` still contains Google's upstream sample, which
talks to the restaurant-finder agent, not to this backend. Adapting it is
Epic 1. We have deliberately not touched it rather than leave a half-converted
client in the repository.

When it lands, it will run against a locally running backend with
`--dart-define=BACKEND_BASE_URL=http://localhost:8000`. No key or secret is
ever passed to the client: the Gemini key and any service credentials live on
the backend only.

## Verify it

A change is not done here until this is green:

```bash
cd backend && make gate
```

That runs, in order: `ruff` lint and format, `basedpyright` in strict mode, a
150-line-per-file budget, a code-smell suite (complexity, dead code,
docstring coverage, dependency hygiene, duplication, typos), the test suite at
**100 % branch coverage**, and a dependency CVE audit. The same commands run in
CI and in the pre-push hook, so the three cannot disagree.

```bash
pre-commit install && pre-commit install --hook-type pre-push
```

## How the repository is laid out

| Path | What |
|---|---|
| `backend/` | The FastAPI service. Start at [`backend/README.md`](backend/README.md) |
| `client_flutter/` | The Flutter client — upstream sample, see above |
| `infra/` | Terraform for the Google Cloud topology ([`infra/README.md`](infra/README.md)) |
| `specs/` | One spec per feature, written before the code ([`specs/README.md`](specs/README.md)) |
| `docs/guides/` | Task-shaped guides — feeding charts from the endpoints, and how a schema is allowed to change ([`docs/guides/README.md`](docs/guides/README.md)) |
| `docs/adr/` | Architecture decisions, each with its rulings and what was rejected |
| `docs/diagrams/` | Mermaid diagrams — one question each ([`docs/diagrams/README.md`](docs/diagrams/README.md)) |
| `docs/compliance/` | SOC 2 / ISO 27001 policies and evidence |

## Where to read next

- **[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)** — how the system is put
  together and why, describing what is built rather than what is planned.
- **[docs/guides/feeding-charts.md](docs/guides/feeding-charts.md)** — how a
  client or the agent gets chart data out of the endpoints, walked end to end
  with real captured responses, and
  **[docs/guides/schema-mutations.md](docs/guides/schema-mutations.md)** — how a
  chart's shape is allowed to change. Both are also published as one
  [PDF](docs/guides/feeding-charts-and-schema-mutations.pdf).
- **[docs/adr/README.md](docs/adr/README.md)** — the decisions, including the
  ones we rejected and the reasons.
- **[docs/diagrams/README.md](docs/diagrams/README.md)** — the same system as
  pictures, in text so they diff in a pull request.
- **[docs/DEV_HARNESS.md](docs/DEV_HARNESS.md)** — how this repository is built
  with Claude Code, which is itself part of the showcase.
- **[CONTRIBUTING.md](CONTRIBUTING.md)** — how to propose a change.
- **[SECURITY.md](SECURITY.md)** — how to report a vulnerability. Please do not
  open a public issue for one.

## Licence

Apache 2.0 — see [LICENSE](LICENSE) and [NOTICE](NOTICE). The Flutter client
derives from Google's `restaurant_finder` sample, also Apache 2.0; files from
it keep their original headers and the Google copyright line.
