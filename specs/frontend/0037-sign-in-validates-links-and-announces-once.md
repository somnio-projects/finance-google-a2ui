# frontend/0037 — Sign-in validates, links link, and the toggle is announced once

**Ticket:** GGU-155, GGU-156, GGU-162 · **Status:** In progress
**Applies to:** `frontend/` (A2UI v0.9) and `frontend_v1/` (A2UI v1.0), identically.

## 1. Problem

Three QA findings on the sign-in screen:

- **GGU-155** — any string reached `accounts:sendOobCode`, `not-an-email` included.
- **GGU-156** — the footer's GitHub and Privacy did nothing when clicked, and the semantics tree exposed each as an `<a>` with no `href` whose name was the URL plus the label twice.
- **GGU-162** — the appearance toggle's accessible name became `Switch to light appearance Switch to light appearance` after one press (label and tooltip both exposed).

## 2. Acceptance criteria

- **AC-1** A syntactically invalid e-mail shows `Enter a valid email address.` under the field and sends no request. Typing again clears it.
- **AC-2** A valid e-mail behaves as before (request, `Check your inbox`).
- **AC-3** Provider rejections never show a raw code: `invalid-email`, `too-many-requests`, `quota-exceeded` and `network-request-failed` have our copy; an SDK sentence passes through only when it reads like one; anything else gets one generic sentence (`firebase_error_copy.dart`).
- **AC-4** GitHub and Privacy open `SignInFooter.github` / `SignInFooter.privacy` in a new tab. On the web they render as real `<a href target=_blank>` (`url_launcher`'s `Link`); on mobile web and elsewhere a tap launches the URL.
- **AC-5** Each footer link is exposed once, with the link role and the accessible name exactly `GitHub` / `Privacy` (no tooltip); it is focusable and Enter activates it.
- **AC-6** The toggle's accessible name is announced once in both states; the tooltip stays for the pointer only; the theme still switches.

## 3. Decisions

- **OD-1 (owner: client team, default taken):** the e-mail check is deliberately shallow (`looksLikeEmail`: one `@`, a dotted domain, no spaces). The provider and registry own the real verdict.
- **OD-2:** `url_launcher` is added (with `url_launcher_platform_interface` and `plugin_platform_interface` as dev dependencies, to fake the launcher in tests). Only `sign_in_footer_link.dart` imports it.
- **OD-3:** the primary button moved to `sign_in_submit_button.dart` to keep the form inside the 150-line budget; the spinner exemption in `transition_rules_test.dart` follows it.

## 4. Tests

`sign_in_validation_test.dart` (no identity call on an invalid address, one call on a valid one), `firebase_error_copy_test.dart`, `sign_in_footer_link_test.dart` (semantics label and link flag, launcher receives each URL on tap and on keyboard activation), `theme_toggle_button_test.dart` (one semantics label in both states).
