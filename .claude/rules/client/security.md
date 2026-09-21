---
description: Client security controls mapped to SOC 2 TSC and ISO/IEC 27001 Annex A — token handling, what a --dart-define may carry, secrets that must never ship in a bundle, logging, TLS, and the deep-link surface. Loads when touching client Dart sources, the web shell or the platform manifests.
paths:
  - "client_flutter/*/lib/**/*.dart"
  - "client_flutter/app/web/**"
  - "client_flutter/app/android/**/AndroidManifest.xml"
  - "client_flutter/app/ios/Runner/Info.plist"
alwaysApply: false
---

# Client security rules (SOC 2 · ISO/IEC 27001)

The rules that apply while writing client code. The control **mapping** —
which TSC and Annex A controls this client satisfies, and which it does not —
belongs in `client_flutter/docs/SECURITY.md`, the client's counterpart to
[`backend/docs/SECURITY.md`](../../../backend/docs/SECURITY.md). **That
document does not exist yet** *(planned — GGU-82, the `feat(client)` PR)*.
Until it does, this file is the whole of the client's written security posture,
and it says only what is true today.

The governing decision is [ADR-B](../../../docs/adr/ADR-B-auth-credential-contract.md).
Everything below either restates a `D-n` ruling from it or follows from one.

## 1. Credentials (CC6.1, CC6.3 · A.5.15, A.5.17, A.8.5)

- The **only** credential is a short-lived Firebase **ID token** (ADR-B D-1). It travels as `Authorization: Bearer <idToken>` on every request to our backend (D-2).
- **The refresh token is never sent to our backend.** It stays inside the Firebase SDK. ADR-B D-1 requires a test asserting the outbound request carries none — write it, and mutation-check it ([`testing.md`](testing.md) §5).
- **`X-A2A-Extensions` is preserved alongside `Authorization`** (D-2). Dropping it makes A2UI *silently* degrade to a text agent: no error, no surfaces. Treat it as a security-relevant line because its failure mode is invisible.
- The token is written into the connector's **mutable header map** before each send — the only seam `genui_a2a 0.10.1` offers (D-9). That map is the single place a token is handled. A token read anywhere else in `lib/` is a review blocker.
- **Refresh policy is exactly:** force-refresh and **one** retry on `auth/expired-token`; **any other** 401 or 403 signs the user out (D-7). No retry loop, no silent re-auth on `auth/invalid-token` or `auth/revoked-token` — those mean the credential is not merely stale.
- `GET /.well-known/agent-card.json` and `GET /health` are unauthenticated by contract (D-3); every other path requires the token. A client that bootstraps by calling anything else before it has a token is calling a route that will 401.

## 2. Storage (CC6.1 · A.8.10, A.8.12)

- Persist the **minimum**, and never the token. Session persistence is the Firebase SDK's job; re-deriving an ID token from the SDK on resume is correct, caching one in `SharedPreferences`, `localStorage`, a cookie or a file is not.
- Nothing derived from a portfolio is written to disk. The payloads are personal financial data; they live for the session and no longer.
- **Web has no secure storage.** Anything the web build persists is readable by any script on the origin. This is a reason to persist nothing, not a reason to reach for a plugin that claims otherwise.

## 3. What a `--dart-define` may carry (CC6.1, CC6.7 · A.5.33, A.8.24)

**A `--dart-define` is compiled into the bundle as plaintext.** In a web build
it sits in the emitted JavaScript, extractable by anyone who opens the app.
`String.fromEnvironment` is const-folded, not fetched.

| May carry | Must never carry |
|---|---|
| `BACKEND_BASE_URL` | any API key — Gemini, Google Maps, analytics, anything |
| a public Firebase config value (project id, app id, public API key) | a Firebase **service account**, a private key, a signing secret |
| a build/release identifier, a feature-flag default | a bearer token, a session secret, a database URL, a password |

The Gemini key lives in the backend and only in the backend — that is the whole
reason the backend holds the model client (ADR-B *Context*). A client that
holds a model key has moved the project's most valuable secret into a
distributable artifact.

Every `--dart-define` is read in `src/config/` and nowhere else
([`architecture.md`](architecture.md) §2). That is enforced: `client.config`
runs `bash tool/check_config.sh` *(lands with GGU-1, PR #30)*.

## 4. Secrets that must never be committed (CC6.7 · A.5.33, A.8.24)

`google-services.json`, `GoogleService-Info.plist`, `*.keystore`, `*.jks`,
`*.p12`, `*.pem`, provisioning profiles, service-account JSON — none of them,
ever (ADR-B D-10). Only Firebase **public** config ships client-side.

These paths are denied to the agent by the repository's permission settings
(root [`CLAUDE.md`](../../../CLAUDE.md) *Do not touch*), and `gitleaks` scans
the full history in CI. Signing material for a real release belongs in the CI
secret store, not in the tree — and no release signing exists yet.

## 5. Logging (CC7.2, CC7.3 · A.8.15)

- Never log a token, an `Authorization` header, a full request, an email, or any portfolio figure. Emails count as personal data here exactly as they do on the backend.
- `avoid_print` is on in `analysis_options.yaml`, so `print` fails `dart.analyze` *(lands with GGU-1, PR #30)*. Use the `logging` package. **That lint stops `print`, not `debugPrint` and not a careless `Logger` call** — it is a syntax check, not a privacy control.
- The app sets `Logger.root.level = Level.WARNING`. Lowering it to `ALL` for debugging is fine locally and is a review blocker in a merged diff, because the alpha `genui`/`a2ui_core` stack logs payload contents at fine levels.
- A failure shown to a user comes from the problem document's `detail`, which the backend guarantees carries no stack trace, SQL or library text. Do not render a caught exception's `toString()` — that is where a URL, a header or a payload fragment reaches the screen.

## 6. Transport (CC6.6, CC6.7 · A.8.20, A.8.26)

- **HTTPS everywhere except a developer's own loopback.** `http://` is acceptable for `localhost`/`127.0.0.1` during development and nowhere else; a non-loopback `http://` backend URL must fail at startup rather than downgrade silently.
- Do not disable certificate validation. A `badCertificateCallback` that returns `true`, an `HttpOverrides` that relaxes trust, or an ATS/`cleartextTrafficPermitted` exception added to `Info.plist` or `AndroidManifest.xml` is a change to the threat model and needs the spec to say why.
- The backend sets HSTS, CSP and the rest of the security headers; the client neither needs nor may weaken them. Whether this app's Flutter web renderer forces `unsafe-eval` into the CSP is **open and unanswered** (GGU-82 OD-3) — it is to be measured, and if it does, the residual risk gets recorded rather than the header quietly loosened.

## 7. Deep links — there is no deep-link surface (A.8.26)

Say this plainly because the absence is the control: **this client has no URL
routes.** [ADR-I](../../../docs/adr/ADR-I-client-routing.md) D-1 keeps
`Navigator` and declines `go_router`; D-2 deletes the ticket's deep-link
acceptance criterion as unimplementable. No custom URL scheme, App Link or
Universal Link is registered in `AndroidManifest.xml` or `Info.plist`.

So there is no untrusted-input path from a link into the app, and no rule to
write about validating one. **If that changes**, it changes here first:
registering a scheme or adopting `go_router` amends ADR-I, and the amendment
carries the input-validation rules for whatever the link can now carry. A
route reachable from outside the app is not a navigation refactor.

Auth gating is a **single component** (ADR-I D-3). Feature views must not
perform their own auth checks — a second check is a second thing to get wrong,
and the two will disagree.

## 8. Dependencies (CC8.1 · A.8.8, A.8.19)

- `genui 0.10.3`, `genui_a2a 0.10.1`, `a2ui_core 0.1.1` are **alpha** and pinned exactly (ADR-D D-4). Pins are not stylistic here; the transport's behaviour moves between releases.
- A new package is named in the PR with the reason, the same as backend dependencies. A package that wants network, storage or platform-channel permissions gets read before it is added.
- The Flutter SDK is pinned in `client_flutter/.fvmrc` and mirrored by `FLUTTER_VERSION` in `client-ci.yaml`; they are changed together or they disagree silently *(both land with GGU-1)*.

## 9. What is enforced

| Rule | Enforced by |
|---|---|
| No `print` | `dart.analyze` *(GGU-1, PR #30)* |
| No endpoint URL outside `config/` | `client.config` *(GGU-1, PR #30)* |
| No credential file in the tree | repository permissions + `gitleaks` over full history in CI |
| **Everything else in this file** | **review only** |

Sections 1, 2, 5, 6 and 7 are review rules. They are written down because
ADR-B and ADR-I made these decisions and nobody should have to re-derive them
from an alpha SDK's source — not because a check will catch a violation.
