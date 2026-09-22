# Client security controls — SOC 2 (TSC 2017) and ISO/IEC 27001:2022 mapping

The companion to [`backend/docs/SECURITY.md`](../../backend/docs/SECURITY.md),
for the Flutter **web** client. Same format, same rule: a row exists only where
the control is implemented in code or configuration **today**, and names where.

A browser client is not a small server. Its surface is different in kind:

- **Everything it ships is published.** The bundle is downloadable by anyone
  who loads the page. There is no such thing as a client-side secret, so
  "protect the credential" is replaced by "never give the client one".
- **Its runtime is the user's browser**, which we do not control and which will
  happily execute anything that reaches the page. The CSP is not a hardening
  nicety here; it is the boundary.
- **Its logs go to the user's console**, where they are visible to the user and
  to any script on the page.
- **Its supply chain runs at the user's machine.** A compromised pub package
  does not breach a server — it breaches every visitor.

## 1. Control matrix — what is implemented

> **⧗ marks a control that is configured but has never been observed working.**
> Every row below carried that marker when GGU-82 was first pushed, because the
> host ran out of disk and the image was never built. **The image has since been
> built and run (2026-09-20), and the markers came off one row at a time, each
> against a running container rather than against the Dockerfile text.** The
> `Verified by` column now says what was actually watched, not what someone
> should type. **No marker remains** — the last one, that `docker compose`
> really applies the hardening it declares, was closed on the compose path
> itself rather than by an equivalent `docker run` (G-11).
>
> Three things the run established that reading the configuration could not
> have, and that are worth a reader's attention because two of them could have
> gone the other way:
>
> - **The app renders under this CSP.** CanvasKit instantiates with
>   `script-src 'self' 'wasm-unsafe-eval'` and the console is clean. Served the
>   same bundle under `script-src 'self'` and the page is blank with
>   *"WebAssembly.compileStreaming(): … blocked by Content Security Policy
>   directive"* — so the narrow directive is **necessary**, and because the page
>   renders with it and nothing else, it is also **sufficient**. `'unsafe-eval'`
>   is not needed and is not present (OD-3, previously reasoned only).
> - **`style-src 'unsafe-inline'` is genuinely required** (G-6), not inherited
>   from a template. The engine injects one `<style>` element
>   (`flutter-view flt-scene-host { … }`) and sets `style` attributes on seven
>   elements; served under `style-src 'self'` the browser reports *"Applying
>   inline style violates … The action has been blocked."*
> - **`BACKEND_BASE_URL` really is a run-time input.** Two containers from the
>   **same image id** served `{"backendBaseUrl":"http://localhost:8000"}` and
>   `{"backendBaseUrl":"https://api.example.test:8443"}`, with the CSP's
>   `connect-src` naming each origin respectively. Repeated on the compose path
>   — `docker compose up`, then `--force-recreate` with a different value,
>   image id `sha256:410f5ccb…` unchanged across both. That is the whole
>   argument for OD-2's artifact identity, and it holds on both paths.
>
> Two smaller things the run turned up, recorded because each would otherwise
> be rediscovered by the next person:
>
> - **`docker run --rm <image> id` does not report the uid.** The entrypoint
>   requires `BACKEND_BASE_URL` and exits 1 before any command argument is
>   reached, so that invocation fails for a reason unrelated to what it asks.
>   Use `--entrypoint id`. Any runbook or CI step checking the uid must say so.
> - **The build still emits `flutter_service_worker.js` under
>   `--pwa-strategy=none`.** It is a **0-byte placeholder**, nothing registers
>   it and the browser never fetches it, so the control holds — but its mere
>   presence in a directory listing looks like the opposite, and an image scan
>   that greps filenames would flag it.

| Control | Implementation | Verified by | SOC 2 TSC | ISO 27001 Annex A |
|---|---|---|---|---|
| Content Security Policy without `unsafe-eval` | `docker/nginx.conf.template` (`script-src 'self' 'wasm-unsafe-eval'`), paired with `flutter build web --csp` in `Dockerfile` | ✓ served header carries exactly one eval token, `'wasm-unsafe-eval'`; the app renders under it with an empty console; under `script-src 'self'` the same bundle is a blank page with a WebAssembly CSP `CompileError` — necessary *and* sufficient | CC6.6 | A.8.26 |
| HSTS, `nosniff`, `Referrer-Policy`, `frame-ancestors`, COOP, `Permissions-Policy` | `docker/nginx.conf.template`, set at server level so no `location` can drop them | ✓ `curl -I` on `/`, on `/config.json` and on a `canvaskit/*.wasm` — all seven headers present on each, so the server-level placement does survive the `location` blocks | CC6.6 | A.8.26 |
| The client reaches exactly one API origin | CSP `connect-src 'self' <backend origin>`, derived at start from `$BACKEND_BASE_URL` | ✓ **the directive**: two containers, same image id, emitted `connect-src 'self' http://localhost:8000` and `connect-src 'self' https://api.example.test:8443`. ✗ **the behaviour** is still unexercised — the app makes no API call at all (G-4); the browser network log shows same-origin requests only | CC6.6, CC6.1 | A.8.20, A.8.23 |
| No CDN dependency at runtime | `flutter build web --no-web-resources-cdn`; CanvasKit is bundled, not fetched from `gstatic.com` | ✓ browser network log for a full page load lists **only** `localhost:3000`, including `canvaskit/chromium/canvaskit.{wasm,js}`; the bundle's `buildConfig` carries `useLocalCanvasKit: true`, which is what makes its `gstatic.com` string a dead branch | CC6.6 | A.8.26, A.5.19 |
| No model key, database credential or service secret in the bundle | there is none to leak: the Gemini key is `SecretStr` server-side and used in exactly one adapter (backend spec 0006). The compose service declares `env_file` as `required: false` because the client has no credentials to load | ✓ recursive `grep -i` over the **served** web root for `AIza`, `api[_-]key` and `BEGIN PRIVATE` matched nothing; the backend-side half is asserted by `test_gemini_client.py` | CC6.1, CC6.7 | A.5.33, A.8.24 |
| Dart source is not republished with the bundle | `flutter build web --no-source-maps`; no `.map` in the image | ✓ `find /usr/share/nginx/html` in the running container returns no `*.map` and no `*.dart` | CC6.7 | A.8.31 |
| Runtime configuration is validated before use | `docker/entrypoint.sh` rejects any `BACKEND_BASE_URL` that is not a bare `http(s)` origin and exits non-zero; it has no default | ✓ both failure runs: unset exits 1 naming the variable; `http://x/"}` exits 1 naming the expected shape. Neither starts nginx | CC6.1, CC7.4 | A.8.28 |
| No service worker caching the app shell | `flutter build web --pwa-strategy=none` | ✓ `navigator.serviceWorker.getRegistrations()` returns `[]` after a full load, and nothing in `flutter_bootstrap.js` or `index.html` registers one. Note the build still *emits* `flutter_service_worker.js`, but it is **0 bytes** and never fetched | CC6.6 | A.8.26 |
| Non-root, read-only container, `no-new-privileges`, health check | `Dockerfile` (uid 101), `docker-compose.yml` (`read_only`, `tmpfs`, `security_opt`) | ✓ **through `docker compose up`, inspected on the container it created** (`finance-a2ui-client-1`): `Config.User=101` and `id` → `uid=101(nginx)`; `ReadonlyRootfs=true`; `SecurityOpt=[no-new-privileges:true]`; `Tmpfs=map[/tmp:]`; `8080/tcp → 3000`. A write to `/usr/share/nginx/html` is refused by the kernel (*Read-only file system*); `docker compose ps` shows `Up (healthy)` and `FailingStreak=0`. Everything `docker-compose.yml` declares is applied — nothing silently dropped | CC6.8 | A.8.9, A.8.19 |
| Base image pinned by digest; the SDK pinned by checksum | `Dockerfile` — both `FROM` lines carry `@sha256:…`, and the Flutter SDK is Google's own release archive verified against the `sha256` its `releases_linux.json` publishes | ✓ the `FROM` lines, plus `sha256sum -c` passing in the build log (`/tmp/flutter.tar.xz: OK`) | CC8.1 | A.8.8, A.8.31 |
| Base-layer security updates applied at build | `Dockerfile` (`apk --no-cache upgrade` in the runtime stage, `apt-get upgrade` in the builder), the same reason the backend runs `apt-get upgrade` | ✓ `apk info -v` diffed against the pinned base image: the step really moves `libssl3`/`libcrypto3` 3.3.3-r0 → 3.3.7-r1, `ca-certificates-bundle` 20241121 → 20260909, `musl` -r9 → -r11, `busybox` -r12 → -r14 | CC8.1 | A.8.8 |
| Build toolchain absent from the served image | multi-stage; the runtime stage copies `build/web` and two config files and nothing else | ✓ in the runtime container `/opt` is empty, there is no `flutter` or `dart` on `PATH`, and no `dart-sdk` anywhere under `/` | CC6.8 | A.8.19 |
| Dart dependencies resolved from a checked-in lockfile | `client_flutter/pubspec.lock`, installed with **`flutter pub get --enforce-lockfile`** so a lock that does not fit fails the build instead of being silently re-resolved | ✓ the build runs it and prints `Got dependencies!`. This is not decorative: at Flutter 3.44.9 the same command fails with *"Unable to satisfy `pubspec.yaml` using `pubspec.lock` … Would change 14 dependencies"* — which is how the SDK pin in G-12 was found | CC8.1 | A.8.8 |
| The client does not compute or format financial figures | ADR-K: the backend ships pre-formatted `*Display` strings; the client binds them | `docs/catalog/CONTRACT.md`, backend `test_package_boundaries.py` | PI1.1 | A.8.28 |

## 2. Gaps — controls we do **not** satisfy

Listed because a mapping that implies a capability we do not have is worse than
no mapping. Each has an owner. None of these is fixed by GGU-82's container PR.

| # | Gap | Why it matters | Owner | Tracked in |
|---|---|---|---|---|
| G-1 | **There is no authentication in the client at all.** `app/lib/src/features/login/bloc/login_bloc.dart` is a fake login: it waits two seconds and emits `success` for any input. No token is requested, received, stored or sent. | Every "where does the token live" question is unanswerable today, and the backend's bearer-token contract is unexercised from the client. Any control about token storage would be fiction. | TL / GGU-1 | `specs/client/0003-*` (contract), GGU-1 |
| G-2 | **Token storage is therefore undecided.** When G-1 is closed, the choice is `localStorage` (readable by *any* script that reaches the page — one injected script is total account compromise, and the CSP is the only thing preventing that), `sessionStorage` (same reachability, shorter life), or in-memory only (safe from storage reads, lost on reload). | The CSP in §1 is what makes any of these survivable; treating it as optional after G-1 lands would be the mistake. | TL | spec `0002` §5, GGU-1 |
| G-3 | **The client does not point at our backend.** `landing_repository.dart:8` hardcodes `http://localhost:10002`, the upstream restaurant-finder A2A sample, and the app still carries that sample's identity (`name: restaurant_finder_client`). | The hardened container currently serves an app that talks to something else. The container is correct; what it serves is not ours yet. | TL / GGU-1 | spec `0002` OD-2 |
| G-4 | **The runtime `/config.json` is written but not read.** The server half is implemented; no code in `app/lib` fetches it. | Until it is read, the "one image per environment" problem is solved on paper only. | TL / GGU-1 | spec `0002` AC-7 |
| G-5 | **No CI enforces any of §1.** There is no `client-ci.yaml`. The non-root uid, the header set, the absence of `unsafe-eval`, the image CVE scan (Trivy), `hadolint` and `shellcheck` are all proven by commands pasted once in a PR and by nothing that runs again. | This is the repo's own stated failure mode: a property everyone believes and nothing checks. Every row in §1 is one refactor away from silently becoming false. | TL / GGU-1 | spec `0002` §9, OD-4 |
| G-6 | **`style-src` keeps `'unsafe-inline'`** — a residual risk, not an oversight, and **now measured rather than assumed**. Served under `style-src 'self'`, the browser blocks the engine's injected `<style>` element and the `style` attributes it sets on seven elements. One honest correction to the earlier wording: the browser *does* offer per-element hashes in the violation report, so a hash path is not theoretically impossible — what does not exist is any supported way to make Flutter emit them, and they would change with every engine revision. | Injected *scripts* are blocked; injected *styles* are not, which leaves CSS-based exfiltration and UI redress inside the page's origin. Accepted for the showcase; revisit if Flutter gains nonce support. | TL | spec `0002` OD-3 |
| G-7 | **The pub dependency tree is not audited or pinned by hash.** `pubspec.lock` pins versions and `pub` verifies package archives against pub.dev, but nothing scans them for advisories the way `pip-audit` scans the backend's, and `genui`, `genui_a2a` and `a2ui_core` are **alpha** packages. | A compromised or abandoned alpha dependency ships straight to every visitor's browser. The backend has `make audit` in its gate; the client has no equivalent. | TL | `specs/client/0001-*`, G-5 |
| G-8 | **The build depends on a network fetch of the SDK at image-build time.** This is narrower than it used to be: the builder no longer uses a community Flutter image (`instrumentisto/flutter`, which has published nothing since 2026-03-27 and whose newest tag cannot satisfy this lock anyway). It is now `debian:12-slim` by digest plus Google's own release archive verified against the `sha256` in `releases_linux.json`, so both halves are immutable and the publisher is the vendor. What remains is that the build is **not hermetic** — it needs `storage.googleapis.com` to be reachable and honest, and the checksum is read from the same file in this repository rather than from an independent channel. The SDK archive is also `x64` only, which is why the builder stage is pinned to `linux/amd64`. | A compromised or unavailable archive host breaks or poisons the build. The checksum makes tampering detectable *if* the checksum itself is trustworthy; committing it here is what gives it a review trail. Fully closing this means vendoring or caching the SDK, which is out of scope for a showcase. | TL | spec `0002` §9 |
| G-9 | **Nothing constrains what the app logs to the browser console.** The client uses `package:logging`; `landing_repository.dart` already logs whole agent responses (`'Text from agent: $text'`). There is no redaction helper and no rule forbidding PII, the way `core/logging.py::redact_sensitive` does server-side. | Console output is visible to the user, to anyone shoulder-surfing a demo, and to any script on the page. Agent responses in a finance app carry portfolio data. | TL / GGU-1 | `specs/client/0001-*` |
| G-10 | **Deep links carry no defined contract.** The app has no router and no deep-link handling yet, so nothing validates what a URL may contain. | When routing lands, an unvalidated path or query parameter becomes an injection point into the surface the agent renders. | TL | `specs/client/0003-*` |
| ~~G-11~~ | **Closed 2026-09-20.** Every row in §1 has been observed against a running container, and the last one — that the flags `docker-compose.yml` *declares* are the ones the container *gets* — was closed through `docker compose up` itself rather than an equivalent `docker run`. `docker compose` will not parse this project without `backend/.env`, which the repo deliberately does not ship; the run used a throwaway overlay that resets the **backend** service's `env_file` (`env_file: !reset null`) and left the `client` service exactly as committed, so no credential was involved and nothing about the service under test was altered. | Kept in the table rather than deleted, because the reason it existed — a mapping must not imply a capability nobody watched — is the point, and because the overlay trick is the cheap way for `client-ci.yaml` (G-5) to do this on every PR without a secret on the runner. | — | spec `0002` §8 |
| G-12 | **`client_flutter/pubspec.yaml` declares an SDK floor that cannot build this workspace, and the real floor is two minors higher than the lockfile admits.** The manifest says `flutter: ">=3.35.7"` / `sdk: ">=3.10.0"`; 3.35.7 ships Dart 3.9.2 and fails version solving outright. But the lock is stricter than its own `flutter: ">=3.44.0"` line suggests: Flutter **3.44.9 still cannot reproduce it**, because the SDK *vendors* some of what the lock pins (3.44 pins `meta 1.18.0` / `vector_math 2.2.0`; the lock holds `1.19.0` / `2.4.2`, which only 3.47.x admits). The Dockerfile therefore installs **3.47.5**, and `pubspec.yaml` is left untouched because the manifest is GGU-1's lane. | The declared floor is not merely stale, it is unbuildable, and nothing had ever installed it — every developer had a newer SDK and there is no client CI. The container is the first thing in this repo to try. Until the manifest is corrected, `pubspec.yaml` advertises a version that would fail for any new contributor who believed it. | TL / GGU-1 | spec `0002` OD-5, §9 |
| G-13 | **The lockfile's own `sdks:` range does not identify the SDK that produced it.** `pubspec.lock` says `flutter: ">=3.44.0"`, and that is a floor derived from package constraints, not a record of the toolchain. The only thing that pins the real one is `flutter pub get --enforce-lockfile` failing. | A build that used the floor would have silently re-resolved 14 dependencies and shipped a different tree than the one reviewed — which is why the Dockerfile passes `--enforce-lockfile` and why `client-ci.yaml` must keep it. The durable fix is for the client to record its SDK version somewhere a human reads (an `.fvmrc`, a CI matrix entry, or a corrected `environment:` block). | TL / GGU-1 | spec `0002` OD-5 |

## 3. Threat notes

- **Script injection is the whole game.** A browser client has no meaningful
  perimeter of its own: the CSP in §1 and the backend's output encoding are the
  controls. This is why `'unsafe-eval'` is absent and why the `--csp` build flag
  and the `script-src` directive must be changed together or not at all
  (spec `0002` OD-3).
- **The bundle is a published artifact.** Treat anything compiled into it as a
  press release. This is the reason `--no-source-maps` is set, and the reason
  `BACKEND_BASE_URL` being public is *not* an argument in either direction for
  spec `0002` OD-2 — it is public either way.
- **Third-party origins.** Read of `app/lib` finds one external URL,
  `https://a2ui.org/specification/v0_9/...`, and it is used as a **catalog
  identifier string**, not fetched. The CSP is written as though nothing
  external is reached, and **the browser network log now confirms it**: a full
  page load issues eight requests, all to the serving origin, and none to
  `a2ui.org`, `gstatic.com` or anything else. If a third-party fetch is added,
  it needs a `connect-src` entry and a row here — a silent CSP widening is the
  failure mode this note exists to catch, and the check that catches it is a
  network log taken again, not this paragraph.
- **The container serves bytes and holds nothing.** It has no datastore, no
  session and no credential. Its only writable surface is a tmpfs `/tmp`
  holding the rendered nginx config and `config.json`; a compromise of the
  container yields the public bundle and the public backend URL.
- **What a compromised *backend* could do to this client** is bounded by the
  CSP's `script-src 'self'`: it cannot inject a remote script tag. It can still
  return hostile *content*, which is why ADR-K forbids the client interpreting
  templates, expressions or field paths from a payload.

## 4. Out of code

Hosting, TLS termination, WAF/Cloud Armor and the CDN in front of this origin
are decided in `specs/client/0002-client-delivery.md` OD-1 and described, once
decided, in `infra/`. Until then the client is reachable through
`docker compose -f client_flutter/docker-compose.yml up` and nowhere else.
(It was a `client` profile in the repository's root compose file until
2026-09-22; that file is now the one stack for the A2UI client, and this app
— a separate deployable — has its own, under the project name
`client-flutter`. Spec `client/0002` AC-6 is restated against it.)

Governance, incident response, data classification and vendor management are
shared with the backend — `docs/compliance/`.
