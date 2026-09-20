# 0002 — Client delivery: how the web client is built, hardened, served and deployed

- **Area:** client
- **Status:** Draft
- **Ticket:** GGU-82 · **Related specs / ADRs:** `specs/client/0001-client-foundation.md`, `specs/backend/0007-cd-pipeline.md`, `specs/infra/0001-dev-environment.md`, [ADR-F](../../docs/adr/ADR-F-google-cloud-platform.md), [ADR-K](../../docs/adr/ADR-K-response-shaping.md)
- **Owner:** Lautaro Bertuzzi · **Date:** 2026-09-20

## 1. Problem

The backend ships a container that is non-root, read-only, digest-pinned and
health-checked, a compliance mapping that says where each control lives, and a
delivery workflow that promotes one image by digest through probe-then-shift.
The Flutter web client has none of it. `docker-compose.yml` said in its own
header that "the Flutter client is not part of the stack yet", so the only way
to run the client was `flutter run -d chrome` on a developer's laptop against
an SDK nobody's version was pinned to — and the only description of how it
would reach an environment was the absence of one.

That gap is not merely untidy. A browser client has a *larger* published
surface than the server it talks to: every byte of the bundle is downloadable
by anyone who loads the page, its CSP is the only thing standing between an
injected script and the user's token, and a wrong `BACKEND_BASE_URL` sends a
finance demo's traffic to the wrong origin. None of that had a written control.

This spec covers the delivery half of GGU-82 (AC-5, AC-6, and open decisions
OD-1/OD-2/OD-3). The folder manual and the client rules are spec `0001`; the
backend contract the client binds to is spec `0003`.

## 2. Scope

**In:**

- `client_flutter/Dockerfile` — multi-stage, digest-pinned, non-root, read-only,
  `no-new-privileges`, health-checked; build toolchain absent from the runtime image.
- `client_flutter/docker/nginx.conf.template` and `docker/entrypoint.sh` — the
  static server, its security headers, and the runtime configuration it renders.
- `client_flutter/.dockerignore`.
- The `client` service in `docker-compose.yml`, behind a profile.
- `client_flutter/docs/SECURITY.md` — the client's control mapping and its gaps.
- The three open decisions below, answered.

**Out:**

- `.github/workflows/client-ci.yaml`, the Flutter half of `.claude/ship-gate.json`,
  the Flutter pre-commit hooks — GGU-1 owns them (PRs #26, #30). This spec names
  the checks it expects there (§9) without adding them.
- A `client-cd.yaml` delivery workflow — it is written once OD-1 is decided, and
  it copies `backend-cd.yaml`'s probe-then-shift shape rather than inventing one.
- Anything under `client_flutter/app/{lib,test,android,ios}` or `app/pubspec.yaml`.
  In particular the app-side loader for `/config.json` (AC-7) is specified here
  and implemented in the client's own lane.

## 3. API contract

The client is not an HTTP API. It is a static origin, and these are the only
paths it answers. Everything is `GET`/`HEAD`; any other method is `405`.

| Method & path | Auth | Response | Notes |
|---|---|---|---|
| `GET /health` | none | `200 text/plain` `ok` | liveness for compose, Cloud Run and the load balancer |
| `GET /config.json` | none | `200 application/json` | `{"backendBaseUrl": "<origin>"}`, written at container start, `Cache-Control: no-store` |
| `GET /` and any unmatched path | none | `200 text/html` (`index.html`) | single-page app: unknown paths are routes, not 404s |
| `GET /<asset>` | none | the built asset | `main.dart.js`, `canvaskit/*`, `assets/*` |

`/health` and **not** `/healthz`: Google's edge intercepts the exact path
`/healthz` on `*.run.app` and answers it before it reaches the container, so a
probe on it proves the edge is up and nothing else (harness log, 2026-09-20).

Every response carries the headers in §5.

## 4. Data model & migration

None. The client has no datastore. The only state the container writes is
`/tmp/nginx/` (the rendered config, the runtime `config.json`, and nginx's
temp paths), which is tmpfs and does not survive the container.

## 5. Security notes

Full mapping, with the gaps, in [`client_flutter/docs/SECURITY.md`](../../client_flutter/docs/SECURITY.md).
The delivery-relevant parts:

**Container.** Runs as uid 101 (the base image's `nginx` user), read-only root
filesystem, `no-new-privileges:true`, `/tmp` as tmpfs, both stages pinned by
digest, Alpine security updates applied at build, and the runtime stage copies
`build/web` and two config files and nothing else — no SDK, no pub cache, no
Dart source.

**Response headers**, set once at server level so no `location` can drop them
(an `add_header` inside a `location` replaces every inherited one — the reason
`Cache-Control` is a `map` here rather than a per-location directive):

| Header | Value | Why this value |
|---|---|---|
| `Content-Security-Policy` | `default-src 'none'`, `script-src 'self' 'wasm-unsafe-eval'`, `style-src 'self' 'unsafe-inline'`, `img-src 'self' data: blob:`, `font-src 'self' data:`, `connect-src 'self' <backend origin>`, `worker-src 'self' blob:`, `child-src blob:`, `manifest-src 'self'`, `base-uri 'self'`, `form-action 'none'`, `frame-ancestors 'none'`, `object-src 'none'` | OD-3 below. `'unsafe-eval'` is **not** present; `'unsafe-inline'` for styles is a residual risk, recorded as such |
| `Strict-Transport-Security` | `max-age=63072000; includeSubDomains` | no `preload`: that is a submission to a browser-vendor list and an irreversible commitment for the parent domain, which is not this container's call |
| `X-Content-Type-Options` | `nosniff` | a mistyped asset must not be re-interpreted as script |
| `Referrer-Policy` | `no-referrer` | the app puts identifiers in the URL; nothing it links to needs to see them |
| `X-Frame-Options` | `DENY` | redundant with `frame-ancestors`, kept for pre-CSP2 user agents |
| `Cross-Origin-Opener-Policy` | `same-origin` | severs the opener reference from anything the page opens |
| `Permissions-Policy` | all of accelerometer, camera, geolocation, gyroscope, magnetometer, microphone, payment, usb denied | the app asks for none of them |
| `Cache-Control` | `no-cache` everywhere, `no-store` for `/config.json` | Flutter's output is **not** content-hashed (`main.dart.js` keeps its name across builds), so nothing may be cached immutably; the ETag makes revalidation a cheap 304 |

**Input validation at start.** `BACKEND_BASE_URL` is interpolated into a JSON
document *and* into a CSP directive, so the entrypoint validates it against
`^https?://[A-Za-z0-9._~-]+(:[0-9]{1,5})?/?$` and exits non-zero otherwise. It
has no default: the same posture as the backend's required settings, where a
missing value crashes at startup rather than degrading into a guess. Shipping a
client silently pointed at the wrong API is the failure this prevents.

**What is public.** Everything in the bundle. There is no client-side secret
and there must never be one: `env_file` is wired into the compose service as
`required: false` purely so a developer can override topology, not because the
client has credentials. The Gemini key stays server-side (backend spec 0006).

**Not covered here:** where the user's token lives in the browser and what a
script injection could do with it. That is the client's own surface and is
mapped — including as a gap — in `client_flutter/docs/SECURITY.md`.

## 6. Open decisions

| # | Question | Owner | Default if unresolved |
|---|---|---|---|
| OD-1 | Where the web client is hosted | **TL** | **Cloud Run** — see below |
| OD-2 | `BACKEND_BASE_URL` compiled in, or read at runtime | **TL** | **read at runtime** — decided, see below |
| OD-3 | Does this app's web renderer force `unsafe-eval` in the CSP | — | **No** — answered empirically, see below |
| OD-4 | Whether the client image is scanned by Trivy in CI like the backend's | **TL** | yes, in `client-ci.yaml`, when GGU-1's workflow lands |
| OD-5 | Whether the stale `environment:` block in `client_flutter/pubspec.yaml` is corrected | **TL** | corrected in GGU-1's lane — see §9 |

### OD-1 — hosting: Cloud Run (default), and why not the two alternatives

| Option | For | Against |
|---|---|---|
| **Cloud Run** *(default)* | one artifact type, one registry, one IAM model, one deploy script and one rollback story for the whole system — `infra/scripts/deploy_cloud_run.sh` already does probe-then-shift and is tested; the security headers travel *inside* the image, so what CI probed is what serves; the container is the unit the compliance mapping describes | pays a container runtime to serve static bytes; a cold start in front of a demo; needs the CDN in front of it to be cheap at any real traffic |
| **GCS bucket behind Cloud CDN** | cheapest and fastest for static files; no runtime to patch | the headers move *out* of the artifact and into load-balancer / `gsutil` metadata — a second place to get the CSP wrong, and one CI cannot probe the way it probes a container; no `/config.json` render step, which would push OD-2 back to a per-environment build; a second deploy mechanism to write and test |
| **Firebase Hosting** | headers and rewrites in `firebase.json` (the repo already has one), global CDN, trivial deploys | a third deploy path and a separate IAM/auth surface outside the Terraform in `infra/`, which ADR-F made the single description of our cloud; the container this spec hardens would go unused |

**Default: Cloud Run**, because the decisive property is that the hardening and
the artifact are the same object. On a bucket, the CSP is configuration applied
beside the files; if it drifts, nothing in the build catches it. In the
container, the header is in the image CI probed, and promotion is by digest.
The cost argument favours the bucket and is real — it is also irrelevant at a
showcase's traffic. **If the TL picks the bucket, the CSP must gain a test that
runs against the deployed origin**, because the in-image proof is what is being
given up. Revisit after the demo, when traffic is a number rather than a guess.

### OD-2 — `BACKEND_BASE_URL` is read at runtime

`--dart-define` makes the value a compile-time constant, so one image could
serve exactly one environment.

The tempting argument — "a value baked in is shipped to every browser" — is
**not** the reason, and stating it would be wrong: the backend base URL is
public either way. It shows up in the browser's network tab on the first API
call whether it arrived in the bundle or in a JSON document.

The real reason is **artifact identity**. `backend-cd.yaml` pushes an image by
digest, deploys that digest with no traffic, probes `/readyz`, shifts traffic,
verifies `/health`, and rolls back otherwise. A per-environment client image
breaks the chain: the artifact CI verified against dev is not the artifact that
reaches production, and the production one is first verified in production.

**So the server writes it.** `docker/entrypoint.sh` renders `/config.json` from
`$BACKEND_BASE_URL` at container start, serves it `no-store`, and puts the same
origin in the CSP's `connect-src`. One image, promoted by digest, same story as
the backend's.

**Honest status.** The server half is implemented and curl-able today. The app
half is not: `client_flutter/app/lib/src/features/landing/repository/landing_repository.dart:8`
holds `const String defaultServerUrl = 'http://localhost:10002';` — a hardcoded
value, not even a `String.fromEnvironment`. Changing it is GGU-1's lane, so it
is AC-7 here and a listed gap in `docs/SECURITY.md`. Until it lands, the image
also bakes `--dart-define=BACKEND_BASE_URL` from the
`BACKEND_BASE_URL_FALLBACK` build arg, so whichever half arrives first works on
its own and the runtime value wins once the loader exists.

### OD-3 — the renderer needs `wasm-unsafe-eval`, not `unsafe-eval`

Answered by loading the served page under the real header and reading the
console, not by reasoning about it. Evidence in the PR body.

- This app uses the **default web renderer, CanvasKit** — `app/web/index.html`
  is the stock bootstrap and nothing selects a renderer, and the build emits
  `canvaskit/canvaskit.wasm` into `build/web`. (The separate HTML renderer no
  longer exists as an option in this Flutter line; the choice is CanvasKit or a
  full `--wasm` build.)
- CanvasKit is WebAssembly, so `script-src` must permit WebAssembly
  instantiation. The narrow directive for exactly that is **`'wasm-unsafe-eval'`**
  (Chrome 97+, Firefox 102+, Safari 16.4+): it permits WebAssembly and nothing
  else — `eval()` and `new Function()` stay blocked.
- The broad **`'unsafe-eval'` is not required**, because the image builds with
  `flutter build web --csp`, which stops dart2js generating code dynamically.
  The flag and the header are a **pair**: remove `--csp` and the page needs
  `'unsafe-eval'`, which would make the CSP worth very little. Anyone touching
  either must touch both.
- **Residual risk, recorded rather than hidden:** `style-src` keeps
  `'unsafe-inline'`. The Flutter engine injects `<style>` elements at runtime
  and there is no supported nonce/hash path for them. An injected script is
  still blocked; injected *styles* are not, which leaves CSS-based exfiltration
  and UI-redress inside the page's own origin. Accepted for the showcase,
  listed in `docs/SECURITY.md`, and revisited if Flutter gains nonce support.
- Also recorded: `img-src`/`worker-src`/`child-src` admit `blob:` because the
  engine decodes images and spawns workers from blob URLs.

## 7. Acceptance criteria

1. **AC-1** — `docker build client_flutter` produces an image whose runtime
   layer contains the built web bundle and no Flutter SDK, pub cache or Dart
   source; both stages are pinned by digest.
2. **AC-2** — `docker run <image> id` reports a non-root uid, and the container
   runs with a read-only root filesystem and `no-new-privileges:true`.
3. **AC-3** — `curl -I` against the running container returns every header in
   §5 with those values; the CSP contains `wasm-unsafe-eval` and does **not**
   contain `unsafe-eval`.
4. **AC-4** — `GET /health` answers `200`, and the container's `HEALTHCHECK`
   reports `healthy`.
5. **AC-5** — `GET /config.json` returns the `BACKEND_BASE_URL` given to the
   container at start — not at build — with `Cache-Control: no-store`; starting
   the container without `BACKEND_BASE_URL`, or with a value that is not a bare
   http(s) origin, exits non-zero with a message naming the variable.
6. **AC-6** — `docker compose up --build` still starts Postgres and the backend
   only; `docker compose --profile client up --build` additionally serves the
   client on `http://localhost:3000`, an origin already in the backend's
   `CORS_ALLOWED_ORIGINS`.
7. **AC-7** *(GGU-1's lane, not satisfied by this PR)* — the app fetches
   `/config.json` before its first API call and uses `backendBaseUrl`, falling
   back to the compiled-in constant only when the fetch fails. Listed as a gap
   in `docs/SECURITY.md` with an owner until then.
8. **AC-8** — `client_flutter/docs/SECURITY.md` maps only controls that are
   satisfied, and lists every unsatisfied one as a gap with an owner.
9. **AC-9** — `cd backend && make gate` stays green.

## 8. Test plan

There is no Dart code in this change, so there are no Dart tests in it. The
subject is a container, and the evidence is the container answering.

| AC | How it is proven | Where |
|---|---|---|
| AC-1 | `docker build` output; `docker run --rm <img> ls /usr/share/nginx/html`; `docker history` / image size | PR body |
| AC-2 | `docker run --rm <img> id`; `docker inspect` of the compose container's `ReadonlyRootfs` and `SecurityOpt` | PR body |
| AC-3 | `curl -I http://localhost:3000/` and `grep` for `unsafe-eval` | PR body |
| AC-4 | `curl -i .../health`; `docker ps` showing `(healthy)` | PR body |
| AC-5 | `curl -i .../config.json` with two different `BACKEND_BASE_URL` values on the **same image id**; a `docker run` with the variable unset and one with a malformed value, both non-zero | PR body |
| AC-6 | `docker compose config --services` with and without `--profile client` | PR body |
| AC-3 (renderer) | the page loaded in a real browser under the real header, console read for CSP violations | PR body (OD-3) |
| AC-9 | `cd backend && make gate` | PR body |

Mutation checks required (auth / rate limit / error masking): **no** — this
service has no authentication, no session and no error bodies of its own. The
equivalent negative checks are the two failure paths in AC-5, which are run.

**Test decision:** no automated test is added in this PR. The checks above are
container-level and belong in `client-ci.yaml`, which GGU-1 owns (OD-4); adding
a second workflow here is exactly what `.claude/rules/ci-conventions.md` §4b
forbids. Until that workflow exists, these properties are proven by the pasted
commands in the PR and by nothing else — which is a weakness, and is written
down in §9 rather than left for a reader to notice.

## 9. Rollout & observability

- **Nothing deploys from this PR.** There is no client delivery workflow yet;
  the container is reachable through compose only. `client-cd.yaml` is written
  after OD-1, and copies `backend-cd.yaml`'s probe-then-shift.
- **Checks this expects in `client-ci.yaml` (GGU-1):** build the image; `docker
  run --rm <img> id` asserting a non-root uid; `curl -I` asserting the header
  set and the absence of `unsafe-eval`; Trivy on the image with the backend's
  CRITICAL/HIGH gate; `hadolint` on the Dockerfile; `shellcheck` on
  `docker/entrypoint.sh`. Each of these is a property this spec claims and that
  **nothing currently enforces** — which is why they are listed by name.
- **A defect this work uncovered, for whoever owns OD-5.**
  `client_flutter/pubspec.yaml` declares `environment: sdk: ">=3.10.0 <4.0.0"`
  and `flutter: ">=3.35.7 <4.0.0"`, but the checked-in `pubspec.lock` resolves
  against `dart: ">=3.12.0"` / `flutter: ">=3.44.0"`. The declared minimum
  Flutter therefore **cannot** build this workspace — `flutter pub get` on
  3.35.7 fails with *"Because showcase_flutter_client_workspace requires SDK
  version >=3.10.0 <4.0.0, version solving failed"*. It was found by building
  the image, which is the first thing in this repo that had ever installed the
  declared version. The Dockerfile pins the version that actually satisfies the
  lock; the manifest is in GGU-1's lane and is not corrected here.
- **Observability:** nginx access and error logs go to stdout/stderr, so Cloud
  Logging picks them up with no agent. They are plain-text, not the backend's
  structlog JSON — a deliberate non-goal for a static file server, and a
  difference a reader of the two log streams should expect.
