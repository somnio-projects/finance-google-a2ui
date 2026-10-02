# 0025 — Failures have a way out

- **Area:** frontend (the two transports, the tabs' failure state, the Assistant's failure card, the router's unknown-route path)
- **Status:** In progress
- **Ticket:** GGU-110 (Holdings never resolves, nav freezes) · GGU-111 (Assistant prints the raw error) · GGU-112 (`/#/home` is an unstyled crash screen)
- **Also:** [frontend/0019](0019-the-turn-always-ends.md) (the stream half of "the turn always ends"), [frontend/0020](0020-transition-states.md) (skeletons), [frontend/0021](0021-three-defects-a-reader-found.md) OD-2 (the Assistant's preserved branch), [`specs/client/0003`](../client/0003-client-backend-contract.md) §4 (branch on `code`, never on `detail`), [ADR-L](../../docs/adr/ADR-L-client-architecture.md) D-8 (errors are values)
- **Owner:** Lautaro Bertuzzi · **Date:** 2026-09-24

## 1. Problem

Three bugs from one manual QA pass (Guillermo Hilal, 2026-09-24, Chrome,
against the deployed preview at `finance-a2ui.firebaseapp.com`, client and
API both at `0.1.0+a8ad309` — `develop`'s head). They read as three defects
and are one: **a failure with no state to land in and nothing to do next.**

1. **GGU-110** — *"Opening the Holdings tab renders the loading skeleton with
   the label `get_holdings()…` and never resolves … While stuck, the bottom
   navigation bar stops responding to taps entirely."* The capture shows the
   two Holdings `GET`s answering **200** and two `POST /` — the agent — at
   **503**.
2. **GGU-111** — tapping the *Biggest drivers* chip after a good first turn
   rendered `model provider unavailable` over `dependency-unavailable`, in red,
   with no retry. Same two `POST / → 503`.
3. **GGU-112** — `/#/home` throws `GoException: no routes for location: /home`
   and renders go_router's default error widget: black on white, no theme.

## 2. Rulings

- **OD-1 — the 503 is the agent's, and Holdings never calls the agent.** The
  reporter read the `get_holdings()…` caption as a model-backed call and the
  `POST / → 503` beside it as its failure. Neither is so: the caption is the
  component's own skeleton text (spec 0015 OD-3, `HoldingsAllocationSkeleton`),
  and `HoldingsBloc` issues exactly two `GET`s and no `POST`. The 503s are the
  Assistant's turns from the same session (GGU-111). Established by reading
  the bloc and by fetching both Holdings payloads from a local stack at the
  same commit: every field the tab binds is present (`positions_payload.py`
  ⇄ `holdings_view.dart`), including `unrealized: null` for the cash row,
  which the tile does not read for cash. **The 200s are real and the tab still
  hung, which is the finding**: the app had two paths that could hang without
  a failure state and one that could not recover from a failure it did show.
  Named below; the ticket's own hypothesis is recorded here so the next reader
  does not chase it.

- **OD-2 — a failure state has a way out, and it is the same request.**
  `TabFailure` was the backend's sentence, centred — an error state with no
  affordance. It now carries *Try again*, which re-issues the tab's first
  event (`HoldingsRequested`, `ActivityRequested`, `HomeRequested`) through
  the bloc that failed. Not a second path: the retry is the load. Home drew
  its own `_Failure` without one; it draws the shared state now. The Assistant
  gets the same shape (OD-4). Moved to `tab_failure.dart` because
  `tab_app_bar.dart` was at 135 lines and the control did not fit.

- **OD-3 — the transport bounds every request and never throws (GGU-110
  AC-3).** Two holes in ADR-L D-8:
  1. Neither client applied a timeout of its own. `FinanceApiClient` *caught*
     `TimeoutException` — a test threw one at it — and nothing ever raised it:
     a stalled connection was a skeleton for as long as the browser cared to
     wait, which is minutes. `defaultTimeout` is now **20 s**, applied to the
     `GET`/`POST` future and to the A2A `send()` (headers back — the stream
     read is long by design and is 0019's problem). Both clients take it as a
     constructor argument so a test injects 20 ms.
  2. The credential was read **outside** the guard. `_headers()` awaited the
     token provider before the `try`, and the provider is the identity SDK
     refreshing over the network. A refresh that threw escaped `getJson` as an
     exception, out of the bloc's handler, to Bloc's `onError` — and the state
     stayed `loading`. Now a value: `TransportFailure(credentialUnavailable)`,
     one sentence shared by both clients, the SDK's own text never shown (N-14).
     No request leaves without its credential.

  One `_send` for both verbs now, which is also the DRY fix the two duplicated
  `try` blocks were asking for.

- **OD-4 — the Assistant's failure card chooses copy by `code`, and offers
  the turn again (GGU-111 AC-1).** `_Failure` printed `failure.message` and
  `failure.code` verbatim. Both are *safe* — that was the rule, and it held —
  but `model provider unavailable` is written for an operator reading a log,
  and the contract says a client branches on `code`, never on `detail`
  (client/0003 §4). So `turnFailureNotice` gives `dependency-unavailable` — the
  one code whose detail is an operator's — a sentence about what to do; any
  other code shows the failure's own `message`. For `transport-unavailable`
  that message is already this client's copy (`the agent could not be
  reached`, `the request timed out`, the credential sentence), written where
  the failure happened and more precise than one sentence could be — the first
  draft collapsed all four into "check the connection", which is wrong for a
  credential read, and review caught it. For a code nobody has met, a sentence
  invented here would be a guess in the tone of a fact. Recorded as the one exception in
  `.claude/rules/frontend/architecture.md` §4.

  *Try again* is `ConversationRetried`: the bloc keeps `lastTurn` — the
  sentence **or** the action `_run` was given — and sends it once more with
  **no echo**, because the bubble that asked is already in the transcript.
  A chip retries as its action, never as its label (0011 OD-3 holds).

- **OD-5 — the chips survive a failed turn (GGU-111 AC-2).** `_run` cleared
  `suggestions` when a turn opened, so after a failure there was nothing to
  fall back on. The state keeps them — they are the last answer's standing
  recommendation — and the **view** hides them while a turn runs. The composer
  was already `enabled: !running`, so a failed turn left it usable; the chips
  were the half that did not.

- **OD-6 — an unknown location is the app's own page; a guessable one is an
  alias (GGU-112).** `errorBuilder` renders `NotFoundPage`: themed, the path
  echoed in mono so a typo can be seen, the exception never, and one control —
  *Go to Home*. `AppRoutes.aliases` names the synonyms a person plausibly
  types (`/home`, `/index`, `/dashboard`, `/portfolio`, `/positions`,
  `/assistant`, `/chat`, `/transactions`), each a `GoRoute` that only
  redirects. Routes rather than error-builder logic, so `/home` never draws a
  not-found frame on its way to `/`, and so the one auth `redirect` still runs
  first: a stranger who knows a synonym lands on sign-in like everyone else.
  An alias is a declared synonym, never a guess — anything not in the map is
  the not-found page.

- **OD-7 — AC-3 of GGU-111, answered: it is the same masked provider error
  as GGU-90's, one layer up.** `gemini_client.py` turns every provider failure
  into `DependencyUnavailableError(UNAVAILABLE)` with a fixed detail and no
  provider text (`core/errors.py`, code `dependency-unavailable`, HTTP 503);
  GGU-90 AC-4 added `provider_errors.log_provider_failure`, so the *reason* is
  in the server's warning log and nowhere the client can or should see it.
  Not a distinct path. Cross-linked in Jira; the backend's masking is correct
  and unchanged — what was wrong was the client showing the mask as copy.

## 3. Acceptance criteria

1. **AC-1** (GGU-110 AC-1) — a failed or timed-out Holdings read renders `TabFailure` with the backend's sentence and *Try again*; the tap re-issues the tab's request and the tab renders. Same on Activity and Home.
2. **AC-2** (GGU-110 AC-3) — a `GET`/`POST` that has not answered within the client's timeout is a `TransportFailure('the request timed out')`; the A2A open, the same. The default is 20 s and is one constant.
3. **AC-3** — a token provider that throws is a `TransportFailure` with the shared sentence, on both clients; no request is sent.
4. **AC-4** (GGU-111 AC-1) — `dependency-unavailable` renders the sentence, not `model provider unavailable` and not the code; *Try again* re-sends the same text or action with no second bubble; `transport-unavailable` and any unknown code show the failure's own message.
5. **AC-5** (GGU-111 AC-2) — after a failed turn the composer is enabled and the previous answer's chips are on screen and tappable.
6. **AC-6** (GGU-112 AC-1) — `/home` is Home; `/nowhere/at/all` is `NotFoundPage` inside the theme, echoing the path, no `GoException` text, and *Go to Home* lands in the shell.
7. **AC-7** (GGU-112 AC-2) — every entry of `AppRoutes.aliases` resolves to its target; a signed-out visit to an alias lands on sign-in.
8. **AC-8** — `cd frontend && make gate` green, 100 % line coverage per file.

## 4. Test plan

| AC | How |
|---|---|
| 1 | `holdings_retry_test.dart`, `activity_retry_test.dart`, `home_retry_test.dart`, `tab_failure_test.dart` — the repository fails, the button is tapped, `fetchPortfolioViews` is verified twice |
| 2, 3 | `finance_api_client_guard_test.dart`, `a2a_client_failures_test.dart` — a `MockClient` that answers after 5 s under a 20 ms limit; a provider that throws, with `sent` asserted empty |
| 4, 5 | `conversation_retry_test.dart` (bloc), `turn_failure_card_test.dart` (the page, one good turn then a failed one), `turn_failure_notice_test.dart` |
| 6, 7 | `app_router_not_found_test.dart` — the real router; the alias case **walks the map** so an alias added later is covered the day it is added |
| all | reproduced first where a test could: the guard suite was written against the old client and failed on `sent` being non-empty and on the exception escaping |

## 5. Out of scope

- **GGU-110 AC-2's freeze itself.** The bottom bar is the shell's, outside every branch, and nothing in this app puts a barrier over it; a tab's bloc cannot reach it. What *can* is a frame that fails to build or lay out — then the last painted frame stays and every tap lands on a screen that never repaints, which matches the report exactly. This PR removes the two ways a screen could sit on its skeleton with nothing to say, and makes the state it lands in recoverable; it does not claim to have seen the freeze. What was tried, and what it would take, is in §6.
- An automatic retry. The person taps; a turn re-run on its own would re-run tool calls whose effects are already on screen (0019 §5 said the same).
- Backend copy. `model provider unavailable` stays as it is: it is a log line's truth and the right thing for `detail` to say to an operator.
- A timeout on the A2A stream body. A turn is long by design; the stream's failure modes are 0019's and are handled there.

## 6. Reproduction record

- Local stack at `791ee7f` (develop's content), token minted inside the backend container, `GET /v1/portfolios/current/views?view=holdings.positions.v1` and the allocation read with the tab's exact options: both 200, 14 positions, cash last, `unrealized: null` on cash only. Every path the tab binds is present.
- Deployed preview: not signed in from this machine, and signing in is not something this workflow does for a person.
- Local web build against the local stack, in a Chrome driven from another window: Holdings sat on its skeleton for 10–45 s after both `GET`s answered, taps on the bar did nothing, and it looked exactly like the report. It was not the report. Timestamped probes put the whole gap **between the bloc's `emit` and the next frame**, and `document.visibilityState` was `hidden`: the driven Chrome was occluded, so the browser stopped `requestAnimationFrame`, and a Flutter web app draws nothing without it. Every "frame" I saw was the one a screenshot forced. Recorded because it will fool the next person too: **a Flutter web repro is only evidence while the tab is visible.** With the tab visible the tab loaded at once, on real payloads, in debug and in release.
- The Holdings freeze therefore stays **unreproduced here**; the fixes are the two hang paths a code reading proves and the missing affordance the report shows.
