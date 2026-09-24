# 0011 — The Assistant, as Flow A, B and C frame it

- **Area:** frontend (+ backend/0029 for the chips)
- **Status:** In progress
- **Ticket:** _unassigned — no GGU number exists for this yet; none is invented here_
- **Also:** [backend/0029](../backend/0029-the-turn-recommends-its-chips.md), [backend/0022](../backend/0022-surface-actions.md) §3, [`frontend/0002-a2ui-agent-path`](0002-a2ui-agent-path.md), [backend/0026](../backend/0026-the-home-shell.md) §2 (the shared palette), [ADR-L](../../docs/adr/ADR-L-client-architecture.md), [ADR-K](../../docs/adr/ADR-K-response-shaping.md) N-9/N-10/N-13
- **Owner:** Lautaro Bertuzzi · **Date:** 2026-09-22

## 1. Problem

The Assistant tab is the product — *"an AI agent answers portfolio questions by
composing UI components instead of text"* — and it was a Material default:
`AppBar('Ask the agent')`, two `Card` bubbles, a `LinearProgressIndicator`,
an outlined `TextField` and a filled send icon. The three Assistant artboards
share one frame and this build matched none of it: no header with the model
pill and the `Simulated` badge, no right-aligned indigo bubbles, no
`Assistant` label with its streaming dots, no skeleton while a surface is
composed, no follow-up chips, no rounded composer with its mic and send.

The transport half already works (0002): turns stream, surfaces resolve
through the one `ComponentRegistry`, failures carry the backend's code. This
spec is the frame around it — and the two taps the design shows that the
client never sent: a follow-up chip and a waterfall bar (0022's `data` part).

## 2. Measured, not transcribed

Read out of `FlowA-Assistant.dc.html` with `getComputedStyle`, light and
dark; Flow B and C share the frame. `HomeTokens` supplies page, header, card,
text, muted, gain, loss and the ticker badge; the rest is `AssistantTokens`.

| Element | Light | Dark |
|---|---|---|
| header | bg `#FDFBFF`, pad 8 14 12, 58 tall; avatar 36×36 r10, gradient 135° `#4F5DFF`→`#7A5CFF`; `Assistant` 17/500 `#1A1B20`; pill `Gemini · A2UI` 10.5/500 `#5F6169` on `#EAE7F5` r8 pad 2×7; badge `Simulated`: `#EAE7F5` r20 pad 5×10, 6px dot `#7A5CFF`, 11/500 `#4A3F8A` | bg `#0E0F13`; title `#E5E1E9`; pill `#C9CBD4` on `#232036`; badge `#232036`, dot `#B9C0FF`, text `#C9CBFF` |
| user bubble | `#4F5DFF`, white 14.5/400, radius 20/20/6/20, pad 11×15, right-aligned, max 62 % of the column, 16 below the header | same |
| assistant label | 22×22 r7 gradient avatar · `Assistant` 12/500 `#5F6169`; while a turn runs, three 6px dots `#7A5CFF` blinking | `#A4A6B0`; dots `#7A5CFF` |
| answer | 14/400 `#1A1B20`, 15 px gutters, verbatim | `#E5E1E9` |
| surface | the component's own card, 15 px gutters, 12 below the answer | — |
| skeleton | card `#FDFBFF` border `#EAE7F0` r18 pad 16 14 14; title bar 120×13 r5, seven bars 37 wide of varying height r4, three pills 60×10 r5, all in a shimmer `rgba(120,120,140,.08)`; `Composing UI…` 10.5/500 `#8A5CF0` with an 8px dot `#7A5CFF` | card `#15161C` border `#24252D` |
| follow-up chips | 12.5/400 `#3A2F70` on `#FDFBFF`, border `#C4C6D0`, r18, pad 8×13, gap 8, one horizontal row above the composer, 15 px in | `#C9CBFF` on `#15161C`, border `#45464F` |
| composer | bar `#FDFBFF` pad 10 12 16; field 48 tall r24 border `#C4C6D0`, placeholder `Ask about your portfolio…` 14 `#8A8D96`, pad 0 16; mic 46×46 circle `#EAE7F5`, glyph `#4A3F8A`; send 46×46 circle `#4F5DFF`, white triangle; send disabled while a turn runs: `#C9C4E8` | bar `#0E0F13`; field border `#45464F`, placeholder `#7C7F89`; mic `#232036`/`#C9CBFF`; send `#B9C0FF`/`#151A54` |

## 3. Rulings

- **OD-1 — the answer is plain.** The artboard bolds `+$3,240 (+0.68%)` in
  green inside the sentence. That is a figure the client would have to find
  in prose and re-style — N-1 through N-4 in one move — so the answer renders
  as the backend wrote it, in one style. If design wants the figure
  emphasised, the backend can send it as a part of its own.
- **OD-2 — the skeleton is a transport state.** Between `render-intent` and
  the fetched payload the transcript shows `SurfacePending`; it is replaced
  in place by the surface (or its unavailability) so nothing reorders (N-10).
  Its shape is the design's — bars and pills, not a spinner.
- **OD-3 — a chip is a `data` part, and it echoes as a user turn.** Tapping
  a chip appends `UserSaid(label)` and opens a turn with
  `{action: ask.suggested.v1, args: {suggestion: key}}`; the backend composes
  the sentence (0022 §3.1). The client never sends the label as text. The
  chips shown are the last turn's `suggestions`, verbatim, and they clear
  while a turn runs.
- **OD-4 — a tapped bar is the other `data` part.** `SurfaceActions`, an
  `InheritedWidget` the conversation page provides, carries one callback;
  `AttributionWaterfallComponent` reads the payload's `actions`, and only
  when `drill.attribution.v1` is declared **and** the tapped key is among its
  published `choices` does a tap send it. A surface rendered on a tab, with no
  scope above it, keeps its local selection and sends nothing. The
  `ViewComponent` seam does not change; adding the callback edited no
  component but the one that declares an action.
- **OD-5 — the mic is drawn and says so.** The design's composer has one;
  this preview has no speech input. It is the honest placeholder pattern of
  frontend/0009 OD-7.
- **OD-6 — the transcript is one lazy list.** Bubbles, labels, answers,
  surfaces and skeletons are entries of one `ListView`, so the streaming
  order is the visual order and a tall surface never pushes the composer.

## 4. Test decision

Package: the parser reads `suggestions` and ignores malformed ones; the A2A
client sends a `data` part with the action id and scalar args and no text
part. Bloc: a `render-intent` appends a pending entry that the fetch
replaces; an answer stores its suggestions; a chip tap echoes the label,
clears the chips and opens the action turn; a bar tap opens the drill turn.
Widget: header words and pills, a user bubble right-aligned, the label with
dots while running and without after, the skeleton while a surface is
pending, chips bound verbatim and tapped, the composer disabled while
running, the mic's honest snack; `AssistantTokens` pinned light and dark.
Component: the waterfall sends the drill action only inside a scope and only
for a declared choice. 100 % line coverage per file, as the gate requires.
Both themes verified by eye against the artboards in the browser.
