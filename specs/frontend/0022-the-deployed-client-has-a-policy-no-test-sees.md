# 0022 — The deployed client has a policy no test sees

- **Area:** frontend (the Content-Security-Policy, both copies of it)
- **Status:** In progress
- **Ticket:** _unassigned — no GGU number exists for this; none is invented here_
- **Also:** [frontend/0017](0017-the-client-runs-in-the-stack-and-ships-itself.md) (the container and the Hosting delivery), [ADR-B](../../docs/adr/ADR-B-authentication.md) D-10 (the Firebase web config is public), [`.claude/rules/ci-conventions.md`](../../.claude/rules/ci-conventions.md) §5
- **Owner:** Lautaro Bertuzzi · **Date:** 2026-09-22

## 1. Problem

`https://finance-a2ui.web.app` served a **white page**. Not a slow page, not a
broken layout — nothing at all, with one line in the console:

```
Executing inline script violates the following Content Security Policy
directive 'script-src 'self' 'wasm-unsafe-eval' https://www.gstatic.com'.
```

Every gate was green. `make gate` was green, `frontend-ci` was green, the
bundle compiled, `/release.json` reported the right commit, and the site was
dead. The TL found it by opening the URL.

**Why nothing caught it.** The client is only ever *tested* without a policy.
`flutter test` runs in a widget harness that has no browser and therefore no
CSP; a local `python3 -m http.server` sends no headers; and `verify_release.sh`
asks the origin for `/release.json`, which is a static JSON file that a broken
app serves perfectly well. The one artefact under test that carries the policy
— `firebase.json` — is data, and nothing read it.

## 2. Rulings

- **OD-1 — the inline script is `firebase_core_web`'s, and it is not
  optional.** `_initializeCore` appends a `<script>` whose **text** it sets:
  a `window.ff_trigger_<service>` function that dynamic-`import()`s the SDK
  bundle from `gstatic`. `script-src` blocks it, the `ff_trigger_` call finds
  no function, `Firebase.initializeApp` throws, and `main()` never renders.
  The `--csp` build flag does not help: it is about Dart's own use of `eval`,
  not about a plugin injecting script text at run time.

- **OD-2 — authorised by hash, not by `'unsafe-inline'`.** Four options were
  weighed:

  | Option | Verdict |
  |---|---|
  | `'unsafe-inline'` | authorises **every** inline script in the document, which is the directive's whole purpose. Refused — `security.md` |
  | a nonce | needs the server to mint one per response; Firebase Hosting serves static files |
  | pre-load the SDK so the plugin's own skip condition (`window.firebase_core != null`) fires | a race against `main()`; a timing fix for a correctness problem |
  | **a hash per snippet** | authorises exactly one byte sequence. **Chosen** |

- **OD-3 — there are four hashes, not one, and that is the plugin's doing.**
  `injectSrcScript` has two branches — one for browsers with Trusted Types
  (Chrome, Edge), one for those without (Safari, Firefox) — and they are
  written with **different indentation**, so they are different bytes. Two
  services are registered (`firebase_core`, `firebase_auth`). 2 × 2 = 4.
  Authorising only Chrome's pair would have left Safari white, which is the
  same defect with a smaller blast radius and a longer time to discovery.

- **OD-4 — the hash is derived, never typed.** A hash is a copy of somebody
  else's source: bump `firebase_core_web`, or add a FlutterFire plugin, and
  the app dies again in production only. `frontend/tool/check_csp_hashes.sh`
  reads the resolved plugin's `supportedFirebaseJsSdkVersion`, rebuilds both
  snippets byte for byte, and fails with the exact string to paste. Same shape
  as the catalog artefacts: **a generated value is gated by regeneration, not
  by trust.**

  It also refuses to pass vacuously — it asserts it examined all eight
  policy × hash pairs, and it fails if `pubspec.lock` carries a FlutterFire
  web plugin the literal service list does not cover, because that plugin
  injects a fifth script nobody has authorised.

- **OD-5 — both policies, one check.** The client is served under **two**
  headers: Firebase Hosting's (`firebase.json`) and the container's
  (`frontend/docker/nginx.conf.template`). They had already been written twice
  and were already allowed to disagree. The check reads both, so a hash added
  to one and forgotten in the other is a red gate rather than a container that
  works and a Hosting deploy that does not.

## 3. Acceptance criteria

1. **AC-1** — `https://finance-a2ui.web.app` renders the sign-in screen with an empty console.
2. **AC-2** — both `firebase.json` and `nginx.conf.template` authorise the four snippets.
3. **AC-3** — removing any one hash from either file fails `make csp`, naming the file, the service, the shape and the string to add.
4. **AC-4** — adding a FlutterFire web plugin without extending the service list fails the check.
5. **AC-5** — `frontend.csp` is in `.claude/ship-gate.json`, in `frontend/Makefile`'s `gate`, and verbatim in `frontend-ci.yaml`; `repo.gate-pairs` is green.
6. **AC-6** — `cd frontend && make gate` green.

## 4. Test plan

| AC | How |
|---|---|
| 1 | the deployed origin, read in a browser with a clean console after the fix |
| 2, 5 | `bash tool/check_csp_hashes.sh` and `bash scripts/check_gate_pairs.sh` |
| 3 | mutation: a hash deleted from `firebase.json` — **measured**, exit 1 with the missing string printed; restored, exit 0 |
| 4 | the plugin-set guard, by inspection of `pubspec.lock`'s current two entries |

## 5. Out of scope

- The `Permissions-Policy` header, which neither file sets. Nothing needs it
  yet; the voice-input work may, and will own it.
- Whether `frontend-cd` should fetch the deployed origin's **rendered** page
  rather than only `/release.json`. A static JSON file cannot tell you the app
  booted, which is exactly how this survived — but proving "it booted" needs a
  headless browser in the pipeline, and that is a decision with a cost, not a
  bug fix. Recorded here so it is not rediscovered.
