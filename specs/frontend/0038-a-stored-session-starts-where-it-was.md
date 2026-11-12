# frontend/0038 — A stored session starts where it was

**Tickets:** GGU-154, GGU-159, GGU-163 · **Status:** In progress
**Amends:** `frontend/0008` (the auth gate), `frontend/0025` OD-2 (*Try again* now also exists at start-up).

## 1. Problem

Three QA bugs, found by E2E on `finance-a2ui-v1.web.app`, in both Flutter apps (`frontend/`, A2UI v0.9, and `frontend_v1/`, A2UI v1.0):

| Ticket | What a signed-in person saw |
|---|---|
| GGU-154 | Cold-loading or reloading `/#/holdings`, `/#/activity` or `/#/ask` landed on Home and rewrote the URL to `/` |
| GGU-159 | When `GET /v1/me/access` answered 429 (`Retry-After: 60`, `rate-limited`), a 5xx, or the network dropped, the sign-in screen — as though logged out |
| GGU-163 | The sign-in screen for 5–7 s on a slow load, while Firebase restored the user and the access check ran |

## 2. One root cause

`AuthGate` had two answers: *shell* or *sign-in*. Every state that was not `signedIn` — `unknown` (nothing asked yet), `provisioning` (the registry has not answered) and the `signedOut` the repository emitted on **any** access-check failure — went to `/sign-in`, and the redirect dropped the location it came from. Once the session resolved, `signedIn` at `/sign-in` went to `/`.

On the web there was a second half: `FirebaseIdentityProvider.currentToken` read `currentUser`, which is null for a moment after start-up while the SDK reads its persisted session.

## 3. The fix

| Layer | Change |
|---|---|
| `finance_core` | `ProblemFailure.retryAfter` — the `Retry-After` delta-seconds beside the problem document (OD-2) |
| `finance_api_client` | the decoder reads `Retry-After` onto a `ProblemFailure` |
| `finance_auth` | two statuses. `restoring`: a stored session being re-checked (distinct from `provisioning`, which belongs to a sign-in on the sign-in screen). `unavailable`: the registry could not answer; the **session is kept** with the failure. `AuthState.isStarting` is `unknown` ∪ `restoring` ∪ `unavailable`. `admission()` decides what an access answer means: only a 401 or 403 problem ends the session (`endsSession`); a bare 401 already ended it through `onUnauthenticated`, which now says so synchronously so the in-flight check cannot overwrite it. `AuthRepository.retry()` re-asks with the kept session — no new link |
| `app/lib/auth` | `FirebaseIdentityProvider.currentToken` waits for `authStateChanges().first` when `currentUser` is null |
| `app/lib/router` | a `/starting` route outside the shell, and `?from=` on both gateways (`gatewayRoute`, `rememberedRoute`) |
| `AuthGate` | three answers: *starting* → `/starting?from=<wanted>`; *signed in* → through, or from a gateway to the remembered location; *anything else* → `/sign-in?from=<wanted>` |
| `features/startup` | `StartupPage` / `StartupBloc` / `StartupView`: the logo tile breathing (`SkeletonPulse`, so reduced motion holds it still) with a `Loading` semantics label; on `unavailable` the failure's own sentence in `TabFailure` with *Try again*, held back for the `Retry-After` window |

The e-mail link needs no change of its own: `SignInPage` already builds the `continueUrl` from the current URL, whose fragment is now `#/sign-in?from=%2Fholdings`, and a person arriving with `#/holdings` is routed through `/starting` and `/sign-in?from=%2Fholdings` and lands there once the link completes.

## 4. Acceptance criteria

- **AC-1 (154)** Cold load of `/holdings` (any in-shell route) with a stored session renders that route and keeps the URL.
- **AC-2 (154)** A reload through either gateway (`/sign-in?from=…`, `/starting?from=…`) lands on the remembered route.
- **AC-3 (154)** After a magic link whose `continueUrl` carries a route, the person lands on that route.
- **AC-4 (154)** An unknown route still resolves to `NotFoundPage`, and the aliases still redirect (GGU-112 unchanged).
- **AC-5 (159)** 429, 5xx and a network failure on `/v1/me/access` render the start-up retry state, never sign-in; the session is kept.
- **AC-6 (159)** *Try again* is not offered inside a `Retry-After` window; with no header it is offered at once.
- **AC-7 (159)** Only a 401 or 403 (or *not provisioned*) routes to sign-in.
- **AC-8 (159)** *Try again* after the window lands on the remembered route with no new magic link.
- **AC-9 (163)** Sign-in is never rendered while a session is being restored; the start-up surface is, and it ends when auth resolves.
- **AC-10** `from` is honoured only for an in-app path: not `//host`, not an absolute URL, not a gateway (no open redirect, no loop).

## 5. Tests

| AC | Test (identical in both apps) |
|---|---|
| 1, 4, 5, 6, 7, 8, 9 | `app/test/router/app_router_startup_test.dart` |
| 1, 2, 3, 5, 10 | `app/test/auth/auth_gate_test.dart` |
| 5, 6, 8 | `app/test/features/startup/bloc/startup_bloc_test.dart` |
| 5, 7, 8 | `packages/finance_auth/test/src/auth_repository_restore_test.dart` |
| 6 | `packages/finance_api_client/test/src/retry_after_test.dart` |
| 9 | `app/test/auth/firebase_identity_provider_test.dart` (waits for the persisted user) |

## 6. Open decisions

- **OD-1 — Retry is offered, not automatic.** Owner: Lautaro. Default: after the window the button appears; nothing re-requests on its own, so a rate-limited backend is not polled.
- **OD-2 — `Retry-After` is decoded with `jsonDecode` in `response_decoder.dart`.** Owner: Lautaro. The numbers rule (`binding_rules_test.dart`) bans `int.parse`/`int.tryParse` from `lib/` because they are how a *figure* is recomputed; `jsonDecode` is already allowed in exactly that file as the transport's decoder. The header is a protocol field nobody sees. The HTTP-date form is not sent by this backend (`rate_limit.py` sends `str(WINDOW_SECONDS)`) and reads as no hint. The alternative — a second allow-listed file for a number mechanism — would widen an exemption whose size is asserted at one.
- **OD-3 — The start-up surface draws the sign-in hero's tile alone, not a skeleton of a screen.** Owner: design. At that point the app does not know whether the shell or the sign-in form comes next, so drawing the shape of either would be a claim. No spinner: `transition_rules_test.dart` reserves those for controls.
- **OD-4 — 403 ends the session.** Owner: Lautaro. It is an answer about the credential (valid and not allowed), so it is treated like 401.
