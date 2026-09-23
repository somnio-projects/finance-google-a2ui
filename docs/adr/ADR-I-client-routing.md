# ADR-I — Client routing and auth gating

- **Status:** **Superseded by [ADR-L](ADR-L-client-architecture.md) (2026-09-22).** Kept for history; never deleted.
- **Gates:** GGU-1, GGU-2 — both against `client_flutter/`, which no longer exists

> **Why it is superseded and not deleted.** This ADR governed `client_flutter/`,
> the older of two Flutter apps, which was retired on 2026-09-22 (spec
> [`repo/0002`](../../specs/repo/0002-retire-the-client-flutter-app.md)). Its
> subject is gone, so it binds nothing today — but ADR-L D-5 is written as an
> *amendment to D-1*, and a citation by number has to resolve. **D-3 is the
> ruling that outlived the app**: ADR-L D-5 restates it verbatim for
> `frontend/` — the auth gate is one `redirect`, never a check inside a
> feature. D-1, D-2 and D-4 are history: `frontend/` adopted `go_router` from
> its first screen, which is the amendment D-4 asked for rather than the
> rediscovery it warned against.

## Context

> **In the context of** a Flutter client that is web-first by mandate and must gate a genui render
> surface behind auth, **facing** a codebase that navigates imperatively via
> `Navigator.pushReplacement` with no `go_router` dependency while GGU-2 specified a `go_router`
> redirect and a deep-linkable `/surface`, **we decided** to keep **Navigator** with a single
> auth-gate component, **and neglected** adopting `go_router`, **to achieve** minimal change and no
> new dependency, **accepting that** web deep-linking, shareable URLs and browser back/forward are
> given up, and that this deviates from `.claude/rules/flutter/code-patterns.md`.

The tickets contradicted each other: GGU-2 scope 4 and AC5 mandated a `go_router` redirect; GGU-1's
technical design explicitly forbade adding it; GGU-2's *own* technical design then reversed its
functional spec back to Navigator. There is no `/surface` route in the app — the genui surface is
hosted inside `LandingPage`.

| | `go_router` | **Navigator (chosen)** |
|---|---|---|
| Deep-link → redirect → return | satisfied | **not possible** |
| Web URL sharing / browser back | native | manual, partial |
| New dependency | +1, all navigation rewritten | none |
| `code-patterns.md` alignment | aligned | deviation, recorded here |

## Decision

- **D-1** **Navigator.** `go_router` is not adopted in Epic 0.
- **D-2** **GGU-2 AC5 is deleted** (deep-link to `/surface` → redirect → post-login return). **GGU-1 AC2 is rewritten** to drop browser back/forward. Neither is implementable without URL routes; leaving them in would make the tickets unclosable.
- **D-3** The auth gate is a **single component**. Feature views MUST NOT perform their own auth checks.
- **D-4** The deviation from `.claude/rules/flutter/code-patterns.md` ("configure `redirect` for authentication flows") is recorded here rather than left implicit, so re-adopting `go_router` later is an amendment rather than a rediscovery.

## Consequences

Playwright E2E cases for deep-link redirect and browser back/forward are dropped; auth persistence
across reload and "canvas paints at all" remain. If Epic 5's shell work needs shareable URLs, this
ADR is amended and the navigation rewrite is paid then.
