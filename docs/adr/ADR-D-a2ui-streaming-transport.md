# ADR-D — A2UI streaming transport

- **Status:** **Proposed** — awaiting TL ratification
- **Gates:** GGU-3, GGU-4 (closes its unmet AC2)
- **Evidence anchor:** `main` @ `410bb9d`

## Context

> **In the context of** GGU-4 having already validated the end-to-end round trip, **facing** the fact
> that its findings were never written down while GGU-2 and GGU-3 both cite it as authority, **we
> decided** to ratify the transport the tree already implements, **and neglected** WebSockets and a
> bespoke `POST /v1/session`, **to achieve** zero rework and alignment with Google's reference SDKs,
> **accepting that** both `genui` and A2UI are alpha, that Cloud Run streaming semantics are
> unvalidated, and that we carry a catalog-id workaround pinned to a genui release.

**This ADR is largely transcription, not fresh decision-making** — which is why it is cheap to write
and why it should be written immediately. GGU-4 is marked `Done` with AC2 (findings captured) and
AC3 (spike branch linked) unmet; `docs/` did not exist. Three of its six findings are recoverable
from the tree and are transcribed below. **Findings 5 and 6 are not derivable from code** and must be
supplied by the spike author.

## Decision

- **D-1** Transport = A2A `message/stream`, JSON-RPC over HTTP POST with `Accept: text/event-stream`, to the service **root**. GGU-3's ticket table row `POST /v1/session` is **withdrawn** — it describes a service that will not be built.
- **D-2** A2UI version = **v0.9** only. The `VERSION_0_8` runner is removed or explicitly marked dead: it fragments session state (see [ADR-A](ADR-A-session-identity.md)).
- **D-3** Terminal task states: `input_required` for a surface awaiting user action, `completed` for a finished order. The client MUST treat `input_required` as a normal, non-error terminal state.
- **D-4** Pinned versions recorded here: `genui 0.10.3`, `genui_a2a 0.10.1`, `a2ui_core 0.1.1`, `a2ui-agent-sdk 0.6.0`, `google-adk >=1.28.1`. Model id resolves `MODEL_NAME` → `LITELLM_MODEL` → `gemini-3.8-flash`.
- **D-5** `useStreaming` MUST NOT be client-controllable in production — it is a client-supplied switch over server behaviour with no auth consideration. Server config only.
- **D-6** The Cloud Run request timeout is set explicitly (not defaulted) and recorded here, with the maximum supported agent turn duration.
- **D-7** `AgentCard.url` MUST advertise the **public** service URL from a `PUBLIC_BASE_URL` setting independent of bind host/port. Today `base_url = f"http://{host}:{port}"` with `--host 0.0.0.0` yields an agent card advertising `http://0.0.0.0:8080` and coin logo URLs pointing at `0.0.0.0`.
- **D-8** The catalog-id override in `landing_repository.dart` is an undocumented pin on a genui version boundary, carrying its own removal condition. It is recorded here so the pin is visible when genui is bumped.
- **D-9** `tasks/cancel` currently always raises `UnsupportedOperationError` while the client calls it on every cancellation. Either implement it or document it as unsupported and stop the client calling it. **Owner required.**

## Open — must come from the spike author, not from code

- **Finding 5 — web render behaviour** under genui's *Limited* web support. This is the project's stated top risk and there is no written evidence the surface was ever rendered on web.
- **Finding 6 — API churn** encountered during the spike.

## Consequences

Ratifying this closes GGU-4's AC2 by naming this ADR as the replacement artifact. Until D-9 has an
owner, every user-initiated cancel produces a server error.
