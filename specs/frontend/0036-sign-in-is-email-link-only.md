# frontend/0036 — Sign-in is e-mail link only

**Ticket:** *unassigned — none is invented here* · **Status:** In progress
**Supersedes in part:** `frontend/0008` (the Google button, OD-8), `frontend/0022` OD-6 (the popup reasoning), `infra/0002` OD-4 (the Google console toggle).

## 1. Problem

The client asked for **Google SSO to be removed**. Both Flutter clients, `frontend/` (A2UI v0.9) and `frontend_v1/` (A2UI v1.0, ADR-M D-9), offered `Continue with Google` above the e-mail field. After this spec the only way in is the e-mail path, which stays exactly as it was: a Firebase sign-in link where a provider is configured (`sendSignInLinkToEmail`), the backend's preview sign-in where none is.

## 2. What goes, in both apps

| Layer | Removed |
|---|---|
| `finance_auth` | `IdentityProvider.signInWithGoogle`, `AuthRepository.signInWithGoogle`, the `NullIdentityProvider` override. `googleNotConfigured` becomes `identityNotConfigured` ("Sign-in is not configured for this build."): the sentence also answered the e-mail methods, and naming it after a button that no longer exists would be a lie |
| `app/lib/auth` | `FirebaseIdentityProvider.signInWithGoogle` (`GoogleAuthProvider`, `signInWithPopup`) |
| sign-in bloc | `SignInGoogleRequested` and its handler |
| sign-in view | the Google button, its painted `G` mark, and the `or` divider that only separated it from the e-mail form |
| theme | `LoginTokens.googleBorder/googleFill/googleText/divider/dividerText` and `googleMark`; no other screen reads them |
| tests | every test of the above; coverage stays 100 % per file |
| docs | `README.md` and `Dockerfile` comments in both apps |

No dependency is removed: the Google button used `firebase_auth`, which the e-mail link still needs, and painted its mark with no asset or package.

## 3. What stays

The e-mail link, the invite-only registry, the preview sign-in, the sign-out, and the request-access sheet are untouched. The backend is untouched: it verifies a Firebase ID token whatever method produced it.

## 4. The CSP is deliberately not changed

`apis.google.com` (script-src, frame-src) and the Firebase auth-domain frame were added for the popup handshake (`frontend/0022` OD-6). Whether the Firebase JS SDK still loads that helper frame on initialisation when no popup is ever opened cannot be shown by a unit test; it needs a browser against a real Firebase project. A policy that is too tight fails sign-in silently, one that is slightly wide costs nothing observable, so the directives, the generated hashes and `firebase.json` are left as they are and only the comments were corrected. Narrowing them is a follow-up that must be verified in a browser on dev.

## 5. Not code

The **Google provider should be disabled in the Firebase console** (Authentication, Sign-in method) for the project. Until then the provider still accepts a token minted outside this client; removing the button removes the door, not the lock.

## 6. Tests

`finance_auth` and both apps' suites keep 100 % line coverage per file. The sign-in view test asserts the screen has no Google button and no `or` divider, and that the e-mail path still submits.
