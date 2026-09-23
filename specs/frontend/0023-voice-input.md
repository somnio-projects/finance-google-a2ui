# 0022 — Voice input

- **Area:** frontend (`frontend/`, the Assistant composer)
- **Status:** In progress
- **Ticket:** _unassigned — no GGU number exists for this; none is invented here_
- **Related:** [frontend/0011](0011-the-assistant-as-designed.md) OD-5 (the mic
  is drawn and says it is not wired — this spec closes it),
  [frontend/0021](0021-three-defects-a-reader-found.md) OD-2 (a control that
  does nothing), [frontend/0017](0017-the-client-runs-in-the-stack-and-ships-itself.md)
  (the two header sets this feature has to change together),
  [ADR-L](../../docs/adr/ADR-L-client-architecture.md) D-2 (the composition
  root), D-8 (failure is a value), D-11 (coverage),
  [`client/0003`](../client/0003-client-backend-contract.md) N-1…N-15
- **Owner:** Lautaro Bertuzzi · **Date:** 2026-09-22

## 1. Problem

The Assistant's composer has a microphone button. Tapping it shows
*"Voice input is not part of this preview yet."* — the honest placeholder
spec 0011 OD-5 chose while there was nothing behind it. There is now a reason
to put something behind it: the showcase's whole claim is that a person asks a
question in their own words and the agent answers by composing UI, and typing
is the least convincing way to demonstrate "in their own words" on a phone-
shaped artboard.

The deployed client is a **web** app on Firebase Hosting, served over HTTPS,
which is a secure context — the only kind in which a browser hands out a
microphone. Chromium and Safari both ship the Web Speech API
(`SpeechRecognition` / `webkitSpeechRecognition`). Firefox does not. Whatever
is built here must therefore be honest about a browser that cannot do it at
all, and about a person who says no to the permission prompt, rather than
leaving a tap with no consequence — which is the defect 0021 OD-2 recorded and
the defect this button currently *is*, one layer down.

## 2. Scope

**In**

- A `SpeechRecognizer` seam in `app/lib/speech/`: an interface, an event union,
  a failure enum, an `UnsupportedSpeechRecognizer`, and one web implementation
  over `dart:js_interop` + `package:web`.
- A `VoiceInputBloc` in the conversation feature that owns one dictation
  session and nothing else.
- The composer's mic: three visible states (unavailable · idle · listening),
  a tooltip per state, and a stated sentence for every way a session can fail.
- `Permissions-Policy: microphone=(self)` in **both** places the client's
  headers are written: `firebase.json` (Hosting) and
  `frontend/docker/nginx.conf.template` (the container).
- `lang="en"` on the bundle's `<html>`, which is what the recognizer reads.

**Out**

- Speech *synthesis* (the assistant talking back). Different API, different
  design, no artboard.
- A native (iOS/Android/desktop) dictation path. `frontend/` deploys as a web
  bundle; a non-web build reports `unavailable` and says so. If a native
  target ever ships, it is a second implementation of the same seam and edits
  nothing else.
- Wake words, continuous dictation, punctuation commands, language selection.
- Any change to what the agent receives. A dictated question is a question.

## 3. API contract

**None.** This feature adds no HTTP surface, no view id, no option and no
payload field. A dictated sentence enters the *existing* agent path —
`ConversationMessageSent` → `AgentRepository.startTurn` — byte for byte as if
it had been typed. That is the point of ruling OD-1 below: voice is an **input
method**, not a second way to talk to the agent.

The one contract this spec does define is the client-internal seam:

```dart
abstract class SpeechRecognizer {
  bool get isSupported;            // can this build dictate at all?
  Stream<SpeechEvent> start();     // one session; the stream ends with it
  Future<void> stop();             // finish the session and keep what was heard
}

sealed class SpeechEvent { }
final class SpeechHeard  extends SpeechEvent { String transcript; bool isFinal; }
final class SpeechFailed extends SpeechEvent { SpeechFailure failure; }

enum SpeechFailure {
  unavailable, permissionDenied, noMicrophone, noSpeech, network, aborted, unknown
}
```

`SpeechFailure` is an enum rather than a sealed class because every member is a
bare kind with no payload, and a `switch` over it is exhaustive either way —
the property ADR-L D-8 is actually asking for. The backend's `AppFailure`
hierarchy is not extended: nothing here crosses a transport boundary and
nothing here has an RFC 9457 document behind it.

## 4. Data model & migration

None. No table, no migration, no persisted value. A transcript lives in bloc
state for the length of one session and in the composer's
`TextEditingController` after it; nothing is stored, cached or logged.

## 5. Security notes

- **The microphone is a new permission surface, and two files grant it.** The
  client ships under a `Permissions-Policy` that today reads `microphone=()` —
  *no origin, including this one, may use it*. A browser enforcing that denies
  `getUserMedia` before the user is ever asked, so the feature would fail on
  the deployed origin and work on a developer's `flutter run`. Both policies
  become `microphone=(self)`; every other directive in the list is left at
  `()`. Hosting's copy is in `firebase.json`, the container's is in
  `frontend/docker/nginx.conf.template`, and spec 0017's rule applies: the two
  header sets are changed in the same commit or the hardening is real on a
  laptop and absent where users are.
- **CSP is not involved and is not touched.** No directive governs microphone
  capture: `media-src` governs the URLs `<audio>`/`<video>` may load, not a
  capture device, and the Web Speech API adds no script origin, no worker and
  no frame. Widening CSP "because audio" would be a change nobody could
  justify from a violation report. It is named here so the next reader does
  not go looking.
- **Audio leaves the device, and this document says so.** Chromium's
  implementation streams the captured audio to a Google recognition service;
  it is not on-device. That is a property of the browser's API, not of
  anything this client does, and there is no client-side switch for it — but a
  showcase that captures a microphone owes the statement. The residual-risk
  row goes in `frontend/SECURITY.md`; no consent dialog of our own is added,
  because the browser's permission prompt is the consent and a second dialog
  in front of it is theatre.
- **Nothing is logged.** No transcript, partial or final, reaches `log()`,
  an analytics call or a request this client makes on its own. The only place
  a transcript travels is the agent turn the person deliberately sends.
- **HTTPS only.** The API requires a secure context; Hosting is HTTPS and
  `localhost` counts as one. An insecure origin surfaces as
  `SpeechFailure.unavailable`, which is stated, not silent.

## 6. Acceptance criteria

1. **AC-1** — On a build whose platform has no Web Speech API, the mic is still
   tappable, its tooltip says voice input is unavailable, and tapping it shows
   a sentence saying why. No tap is silent.
2. **AC-2** — On a supported build, tapping the idle mic starts a session: the
   button becomes a stop control with its own tooltip.
3. **AC-3** — A partial transcript appears in the composer field while the
   person is still speaking, and the caret sits after it.
4. **AC-4** — A final transcript stays in the composer. **It is not sent.**
   The person presses Send, exactly as after typing.
5. **AC-5** — Tapping the stop control ends the session, returns the button to
   its idle shape, and keeps what was heard.
6. **AC-6** — A denied microphone permission, a missing microphone, a network
   failure, silence (`no-speech`), an aborted session and an unrecognised
   engine error each produce their own stated sentence and return the button
   to idle.
7. **AC-7** — Two consecutive failures of the same kind produce two notices.
   (The first cut of this feature de-duplicated on the failure value and the
   second tap was silent — 0021 OD-2, one layer in.)
8. **AC-8** — A dictated question reaches the agent through
   `ConversationMessageSent` and nothing else; no second call path exists.
9. **AC-9** — `Permissions-Policy` names `microphone=(self)` in `firebase.json`
   **and** in `frontend/docker/nginx.conf.template`, and the two header values
   are otherwise unchanged.
10. **AC-10** — No file in `app/lib` outside `app/lib/speech/speech_web.dart`
    imports `dart:js_interop` or `package:web`, and nothing outside
    `bootstrap.dart` resolves the platform recognizer.
11. **AC-11** — `cd frontend && make gate` green: 150-line budget, layering,
    binding rules, 100 % line coverage per file.

## 7. Test plan

| AC | Test |
|---|---|
| AC-1, AC-2, AC-5, AC-6, AC-7 | `app/test/features/conversation/bloc/voice_input_bloc_test.dart` — a `FakeSpeechRecognizer` scripts each event sequence; the complete state sequence is asserted |
| AC-3, AC-4 | `app/test/features/conversation/view/voice_composer_test.dart` — the real composer, the real controller: the field carries the partial, then the final, and `AgentRepository.startTurn` is **not** called until Send |
| AC-6 | `app/test/speech/speech_failure_test.dart` — every documented Web Speech error code maps to its kind, and an unknown one to `unknown` |
| AC-1 | `app/test/speech/speech_recognizer_test.dart` — `UnsupportedSpeechRecognizer` reports `isSupported == false` and its stream is a single `SpeechFailed(unavailable)` |
| AC-8 | the existing `conversation_*_test.dart` suites, unchanged — a dictated question is the typed path |
| AC-9 | `frontend/test/tool/permissions_policy_test.dart` — the two files are read and their `Permissions-Policy` values compared to each other |
| AC-10 | `app/test/architecture/speech_rules_test.dart` — mutation-checked both ways |
| AC-11 | `make gate` |

**Test decision.** Bloc, widget and a structural rule; no golden. The mic
button's two states differ by fill and glyph, both of which are constants
asserted directly — a golden of a 46 px circle would be the noisy half of the
ADR-L D-15 trade with none of the signal. Nothing here is a chart and nothing
here is a number.

## 8. Rulings

- **OD-1 — dictation fills the composer; it does not send.** The alternative
  (submit on the final result) is one tap shorter and was rejected: the engine
  returns a *best guess*, the person cannot see it until it lands, and an
  auto-sent mishearing costs an agent turn and a line of transcript that
  cannot be taken back. Filling the field keeps the person's hand on the
  trigger and makes voice an input method rather than a second conversation
  channel — which is also what keeps AC-8 true. Revisit when there is a design
  page that says otherwise.

- **OD-2 — the browser sits behind one interface, and the bloc never sees
  it.** `VoiceInputBloc` takes a `SpeechRecognizer`. `bootstrap.dart` picks the
  implementation through a conditional import and publishes it, so the bloc is
  driven by a fake in every test and the layering test stays true. The
  conditional import lives **in the composition root itself** rather than in a
  `speech_platform.dart` barrel: a barrel of one conditional export is a file
  with no executable line, which lcov does not record and the coverage gate
  would then have to excuse. Putting the choice where ADR-L D-2 already says
  construction lives costs one import line and no exemption.

- **OD-3 — one coverage exemption, `app/lib/speech/speech_web.dart`, and
  everything that can be moved off it has been.** A library importing
  `dart:js_interop` cannot be compiled for the VM, so `flutter test` can never
  load it and lcov can never write a record for it. This is the second
  exemption in `tool/coverage_sources.dart` after `lib/main.dart`, and it is
  the same *kind*: a file whose only content is the boundary between this app
  and something a test cannot start. What keeps it narrow:
  - the error-code mapping is **not** in it — `speech_failure.dart` is pure
    Dart, fully tested, and holds the one decision worth getting wrong;
  - the state machine is **not** in it — that is the bloc;
  - what is left is construction, four callback registrations and reading a
    transcript out of a JS object.
  - it is compiled for real by `flutter build web --release`, which
    `frontend-ci`'s `build` job runs on every pull request. *That* is the
    check that this file is not broken; coverage never was going to be.

- **OD-4 — a notice carries a counter, because a sentence is not a state
  change.** Bloc emits equal states and `BlocListener` does not fire twice for
  the same one, so two denied permissions in a row would show one snackbar and
  the second tap would be silent — the 0021 OD-2 defect, rebuilt. The state
  carries `notices`, incremented on every notice, and the listener keys on it.
  AC-7 is that assertion.

- **OD-5 — the sentences are the client's, and that does not breach N-1.** The
  contract-binding rule says a client never writes prose the backend owns.
  These sentences are about the *device*: whether this browser has the API,
  whether the person granted the microphone, whether anything was heard. No
  server knows any of it, and there is no payload field that could carry it.
  They are kept in one file, `voice_notice.dart`, as a `switch` over
  `SpeechFailure` that is exhaustive by compilation — so a new failure kind is
  a compile error rather than a silent blank. No figure, no date and no money
  is formatted anywhere in this feature.

- **OD-6 — the mic borrows the send button's active palette; no colour is
  invented.** There is no artboard for a listening microphone. Rather than
  measure nothing and ship a guess, the listening state uses
  `AssistantTokens.send` / `sendGlyph` with `Icons.stop_rounded`, which are
  already the composer's "this control is live" colours. `AssistantTokens`
  gains no field, `assistant_palettes.dart` gains no literal, and the day a
  page exists the change is two constants.

- **OD-7 — one utterance per tap: `continuous = false`, `interimResults =
  true`.** Continuous mode keeps the microphone open until something stops it
  and turns a forgotten tab into an open microphone. A single utterance ends
  by itself, which also makes `no-speech` a real, reachable outcome instead of
  an indefinite wait. Interim results are on because AC-3 is the difference
  between dictation that feels alive and a button that does nothing for four
  seconds.

- **OD-8 — no dictation plugin.** `speech_to_text` and the rest are
  plugin-based, carry native iOS/Android implementations, and their web
  support is a thin wrapper over the same API this seam calls directly. The
  cost of the package is a platform channel, a permissions plugin, an Android
  manifest and a Podfile in a repository that ships one web bundle; the
  benefit is a wrapper around ~90 lines. ADR-L D-13 rejected a chart library on
  the stronger version of this argument (the library broke a product
  invariant); this is the weaker, ordinary version — it does not pay.

- **OD-9 — the recognition language comes from the document, and the document
  now declares one.** `SpeechRecognition.lang` defaults to the `<html lang>`
  attribute and, failing that, to the user agent's language. The bundle's
  `index.html` declared none, so a Spanish-locale browser would have dictated
  Spanish into an English-speaking agent. Adding `lang="en"` to `<html>` is
  the standards-correct fix (it is also what a screen reader reads), it is one
  attribute, and it keeps the recognizer free of a hard-coded locale constant
  that `AppConfig` would otherwise have to own. The Dart code sets `lang`
  **not at all**, on purpose.

- **OD-10 — no permission pre-flight.** `navigator.permissions.query({name:
  'microphone'})` is not implemented uniformly and answers `prompt` in the
  common case, which tells the UI nothing it can act on. The session is simply
  started; a denial arrives as `not-allowed` and becomes a sentence. One code
  path, no speculative branch that a test would have to fake.

## 9. Rollout & observability

No flag, no migration, no metric. The feature is visible the moment the bundle
ships and is self-describing on a browser that cannot run it.

The one deployment-shaped step is AC-9: `Permissions-Policy` must change in
both files **before** a build carrying this feature is released, or the
deployed client will report a permission failure that a laptop never shows.
`frontend-cd` reads `/release.json` back off the preview channel before it
releases to live (spec 0017); a manual tap of the mic on that preview URL is
the check this feature actually needs, and it is named in the PR's
`Verification` block.
