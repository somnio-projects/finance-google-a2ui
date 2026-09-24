# 0008 — Sign-in: the door, and who holds the key

- **Area:** frontend (+ backend/0027 for the registry)
- **Status:** In progress
- **Ticket:** _unassigned — GGU-115 is a local number_
- **Also:** backend/0027 (user provisioning), [ADR-B](../../docs/adr/ADR-B-auth-credential-contract.md) D-1/D-7/D-10/D-13, [ADR-I](../../docs/adr/ADR-I-client-routing.md) D-3, `frontend/SECURITY.md` G-1..G-3
- **Owner:** Lautaro Bertuzzi · **Date:** 2026-09-21

## 1. Problem

`Login.dc.html`: *"Firebase Auth with gated, invite-only provisioning.
Sign-in-first: no open self-signup. Material 3, mobile 390×844. Semantic
finance colors reserved for data screens; this screen stays calm and
neutral. Three states shown per theme."* The app had no door: a development
token compiled into the bundle (G-1) let anyone in until it expired, and then
showed the tab bar with an error where the design shows a sign-in screen.

## 2. Measured, not transcribed

Read out of the rendered page, light and dark (`LoginTokens`):

| Element | Light | Dark |
|---|---|---|
| page | `#FDFBFF` | `#0E0F13` |
| logo 64 r20, gradient `#4F5DFF → #7A5CFF`, shadow `0 8 20 -6 rgba(79,93,255,.55)` | both | both |
| title 26/400 ls −.3 · pitch 14.5/400 lh 1.5 max 280 | `#1A1B20` · `#44464E` | `#E5E1E9` · `#B6B8C2` |
| Google 52 r26 15/500 | border `#C4C6D0` fill `#FFF` text `#1A1B20` | `#45464F` · `#1B1C22` · `#E5E1E9` |
| `or` 12, rule 1px, margin 22 | `#8A8D96` · `#E3E2E6` | `#8A8D96` · `#2A2B31` |
| field 56 r8, label 12 floating, hint 15 | border `#C4C6D0`, focus 2px `#4F5DFF`, label `#5F6169`, hint `#8A8D96` | `#45464F` · `#B9C0FF` · `#A4A6B0` · `#7C7F89` |
| helper 11.5 (L2) | `#5F6169` | `#A4A6B0` |
| primary 52 r26 15/500 | `#4F5DFF` on white | `#B9C0FF` on `#151A54` |
| invite 12.5 · link underlined | `#5F6169` · `#9AA0AA` | `#A4A6B0` · `#6F7280` |
| footer 11.5 · links · `·` | `#8A8D96` · `#4F5DFF` · `#C4C6D0` | `#7C7F89` · `#B9C0FF` · `#45464F` |
| snackbar (L3) r8 14/16 | `#322F35`, text `#E6E1E6`, `!` `#FFB4AB`, Dismiss `#B9C0FF` | `#E6E1E6`, `#1A1B20`, `#C0362C`, `#4F5DFF` |

Padding 56 / 28 / 28 on the 390 artboard; the column is capped at 390 on a
wide window.

## 3. Rulings

- **OD-1 — two questions, two seams.** `IdentityProvider` (pure Dart
  interface in `packages/finance_auth`) answers *who*; `AccessGateway` asks
  the backend *whether* (`GET /v1/me/access`). `AuthRepository` joins them
  into one `AuthState`; a token the registry does not know leaves the person
  `notProvisioned` with the backend's sentence and no session.
- **OD-2 — Firebase is the provider, in `app/lib/auth/` and nowhere else.**
  `firebase_auth` is a Flutter plugin, so the adapter cannot live in
  `packages/`; `layering_test.dart` confines the import to the adapter, the
  composition root and `main.dart`. Tested with `mocktail` mocks of the SDK.
- **OD-3 — the local stack has no Firebase.** `AppConfig.firebase` is null
  without `FIREBASE_API_KEY`; the seam is `NullIdentityProvider`, the Google
  button says *Google sign-in is not configured for this build.* and the
  e-mail button calls the backend's preview sign-in (backend/0027 OD-3).
- **OD-4 — e-mail through Firebase is a sign-in link**, not a password: the
  design has no password field. The link returns to `/sign-in`; the screen
  recognises it (`isSignInWithEmailLink`) and asks the person to confirm the
  address rather than storing it in the browser.
- **OD-5 — one gate.** `AuthGate` is a `Listenable` over the repository;
  `buildRouter(gate:)` uses it as `refreshListenable` and the single
  `redirect` (ADR-I D-3). `/sign-in` sits outside the `StatefulShellRoute`,
  so a stranger sees no tab bar. Tests that pump one route pass no gate.
- **OD-6 — 401 is the end of the session.** `FinanceApiClient.onUnauthenticated`
  fires once per 401 on an authenticated call; the repository signs out and
  the gate redirects. The A2A stream client does not carry the hook yet (G-2).
- **OD-7 — sign-out is the avatar.** The design's header has no menu; the
  avatar opens a two-line sheet with `Sign out`, which clears the provider,
  the views cache (G-3) and the state.
- **OD-8 — Google at the IdP is one console toggle away.** Firebase's REST
  API refuses to enable the Google provider without an OAuth client id
  (`INVALID_CONFIG : client_id cannot be empty`), which only the console
  creates. Everything else is set: `localhost` is an authorized domain and
  e-mail-link sign-in is enabled on project `finance-a2ui`; the dev backend
  already trusts `securetoken.google.com/finance-a2ui`.

## 4. Test decision

Package: the repository's state machine over a scripted provider and a fake
backend behind the real `FinanceApiClient` (every path, including the 401
and the not-provisioned branch). App: the Firebase adapter with SDK mocks;
the gate's redirects; the bloc's every event; the page at 390×844 in both
themes — the three design states, the link return, the request sheet, the
sign-out from the Home avatar. 100 % line coverage per file.
