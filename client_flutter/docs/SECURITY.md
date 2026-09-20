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

| Control | Implementation | Verified by | SOC 2 TSC | ISO 27001 Annex A |
|---|---|---|---|---|
| Content Security Policy without `unsafe-eval` | `docker/nginx.conf.template` (`script-src 'self' 'wasm-unsafe-eval'`), paired with `flutter build web --csp` in `Dockerfile` | `curl -I` in the GGU-82 PR; the page loaded under the header with a clean console | CC6.6 | A.8.26 |
| HSTS, `nosniff`, `Referrer-Policy`, `frame-ancestors`, COOP, `Permissions-Policy` | `docker/nginx.conf.template`, set at server level so no `location` can drop them | `curl -I` in the GGU-82 PR | CC6.6 | A.8.26 |
| The client reaches exactly one API origin | CSP `connect-src 'self' <backend origin>`, derived at start from `$BACKEND_BASE_URL` | `curl -I` shows the rendered directive; browser network log shows no third-party request | CC6.6, CC6.1 | A.8.20, A.8.23 |
| No CDN dependency at runtime | `flutter build web --no-web-resources-cdn`; CanvasKit is bundled, not fetched from `gstatic.com` | `ls` of the image's `canvaskit/`; network log shows no external script | CC6.6 | A.8.26, A.5.19 |
| No model key, database credential or service secret in the bundle | there is none to leak: the Gemini key is `SecretStr` server-side and used in exactly one adapter (backend spec 0006). The compose service declares `env_file` as `required: false` because the client has no credentials to load | `grep` over `build/web` in the GGU-82 PR | CC6.1, CC6.7 | A.5.33, A.8.24 |
| Dart source is not republished with the bundle | `flutter build web --no-source-maps`; no `.map` in the image | `find` over the image's web root | CC6.7 | A.8.31 |
| Runtime configuration is validated before use | `docker/entrypoint.sh` rejects any `BACKEND_BASE_URL` that is not a bare `http(s)` origin and exits non-zero; it has no default | the two failure runs pasted in the GGU-82 PR | CC6.1, CC7.4 | A.8.28 |
| No service worker caching the app shell | `flutter build web --pwa-strategy=none` | absence of `flutter_service_worker.js` in the image | CC6.6 | A.8.26 |
| Non-root, read-only container, `no-new-privileges`, health check | `Dockerfile` (uid 101), `docker-compose.yml` (`read_only`, `tmpfs`, `security_opt`) | `docker run --rm <img> id` and `docker inspect` in the GGU-82 PR | CC6.8 | A.8.9, A.8.19 |
| Base images pinned by digest, not by tag | `Dockerfile` — both stages carry `@sha256:…` | the `FROM` lines | CC8.1 | A.8.8, A.8.31 |
| Base-layer security updates applied at build | `Dockerfile` (`apk --no-cache upgrade`), the same reason the backend runs `apt-get upgrade` | build log in the GGU-82 PR | CC8.1 | A.8.8 |
| Build toolchain absent from the served image | multi-stage; the runtime stage copies `build/web` and two config files and nothing else | image contents and size in the GGU-82 PR | CC6.8 | A.8.19 |
| Dart dependencies resolved from a checked-in lockfile | `client_flutter/pubspec.lock`; the image builds with `--frozen` semantics by resolving from the lock | build log | CC8.1 | A.8.8 |
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
| G-6 | **`style-src` keeps `'unsafe-inline'`** — a residual risk, not an oversight. The Flutter engine injects `<style>` elements at runtime with no supported nonce or hash path. | Injected *scripts* are blocked; injected *styles* are not, which leaves CSS-based exfiltration and UI redress inside the page's origin. Accepted for the showcase; revisit if Flutter gains nonce support. | TL | spec `0002` OD-3 |
| G-7 | **The pub dependency tree is not audited or pinned by hash.** `pubspec.lock` pins versions and `pub` verifies package archives against pub.dev, but nothing scans them for advisories the way `pip-audit` scans the backend's, and `genui`, `genui_a2a` and `a2ui_core` are **alpha** packages. | A compromised or abandoned alpha dependency ships straight to every visitor's browser. The backend has `make audit` in its gate; the client has no equivalent. | TL | `specs/client/0001-*`, G-5 |
| G-8 | **The builder image is a third-party Flutter distribution** (`instrumentisto/flutter`), pinned by digest. Google publishes no official Flutter container image, and the Linux SDK archive it does publish is `x64` only. | Digest pinning makes the artifact immutable and auditable, but the *provenance* is a community publisher, not the vendor. The mitigation available today is the pin plus the CVE scan that G-5 says does not run yet. | TL | spec `0002` §9 |
| G-9 | **Nothing constrains what the app logs to the browser console.** The client uses `package:logging`; `landing_repository.dart` already logs whole agent responses (`'Text from agent: $text'`). There is no redaction helper and no rule forbidding PII, the way `core/logging.py::redact_sensitive` does server-side. | Console output is visible to the user, to anyone shoulder-surfing a demo, and to any script on the page. Agent responses in a finance app carry portfolio data. | TL / GGU-1 | `specs/client/0001-*` |
| G-10 | **Deep links carry no defined contract.** The app has no router and no deep-link handling yet, so nothing validates what a URL may contain. | When routing lands, an unvalidated path or query parameter becomes an injection point into the surface the agent renders. | TL | `specs/client/0003-*` |

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
  external is reached, and the browser network log in the GGU-82 PR is the
  check that this stays true. If a genuine third-party fetch is ever added, it
  needs a `connect-src` entry and a row here — a silent CSP widening is the
  failure mode this note exists to catch.
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
`docker compose --profile client up` and nowhere else.

Governance, incident response, data classification and vendor management are
shared with the backend — `docs/compliance/`.
