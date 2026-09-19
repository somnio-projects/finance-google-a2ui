# Contributing

Thanks for looking. This is an open-source **reference application**, so the
bar is a little unusual: the point is not only that it works, but that someone
can read it and learn how to build the same thing. A change that works but
cannot be explained is not finished here.

## Before you open a pull request

```bash
cp backend/env.example backend/.env
pre-commit install && pre-commit install --hook-type pre-push
cd backend && make gate
```

`make gate` is the definition of done, and it is the same set of commands CI
runs — lint, strict type checking, a 150-line-per-file budget, a code-smell
suite, tests at **100 % branch coverage**, and a dependency CVE audit.

**Thresholds go up, never down.** If coverage or a linter blocks you, the
answer is a test or a smaller module, not a lowered bar or a `# noqa`. If you
genuinely believe a threshold is wrong, say so in an issue — that is a team
decision, not a fix inside a feature change.

## How a change is shaped

1. **Start with a spec.** Anything beyond a typo begins as a short document in
   [`specs/`](specs/README.md) with numbered acceptance criteria. It is the
   contract the code, the tests and the pull request all cite.
2. **Branch from `develop`**, named `type/short-description`. Every pull
   request targets `develop`; `main` only receives a release.
3. **Implement in layer order** — migration, model, schema, repository,
   service, controller — with the tests beside each file. The layering is
   enforced by tests that read the parsed source, so a shortcut will fail
   rather than slide through.
4. **Update the documentation in the same change.** A structural change updates
   its [diagram](docs/diagrams/README.md); a behaviour change updates the
   document that describes it. A pull request that leaves either stale is
   incomplete.
5. **Open the pull request** with the spec reference, the acceptance criteria
   it satisfies, the real gate output, and a **manual run** — the actual
   commands against a running stack with their actual responses pasted in. A
   claim that it works is not evidence that it works.

## What we will ask you to change

- A number formatted or computed anywhere but the one display module.
- The model computing a figure instead of copying one a tool produced.
- A new chart that required editing a shared list, an enum or an `if/elif`
  chain. Adding one should cost exactly one new module.
- An error response carrying a stack trace, a SQL fragment or a library
  message.
- A secret, a key or a `.env` file — see below.
- A test that executes a line without asserting anything about it.

## Secrets

Never commit one. `.env` files are git-ignored, the repository's tooling denies
reading them, and a secret scanner runs over the **entire git history** in CI —
not just the diff. The model key and any service credentials live on the
backend only and are never passed to the client.

If you believe a secret has been committed, **do not open a public issue**.
Follow [SECURITY.md](SECURITY.md).

## Reporting something

- **A bug or a request** — open an issue; the templates ask for what we need.
- **A vulnerability** — [SECURITY.md](SECURITY.md), privately, please.
- **A question about the architecture** — read
  [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) and the
  [ADRs](docs/adr/README.md) first. They record what was rejected and why,
  which is usually the part you are looking for.

## Licence

By contributing you agree that your contribution is licensed under the
Apache License 2.0, the same as this project. See [LICENSE](LICENSE) and
[NOTICE](NOTICE).
