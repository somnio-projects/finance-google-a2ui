# 0012 — Details the review found

- **Area:** frontend
- **Status:** In progress
- **Ticket:** _unassigned — no GGU number exists for this yet; none is invented here_
- **Also:** [backend/0026](../backend/0026-the-home-shell.md) (the Home shell), [backend/0030](../backend/0030-the-greeting-names-the-caller.md)
- **Owner:** Lautaro Bertuzzi · **Date:** 2026-09-22

## 1. What the review of the running app asked for

- **The question rail has a way back.** The Home chips fade and offer an
  arrow on the right while more are off-screen; once the reader has gone
  right there was no way back but a drag. The left edge now fades the same
  way and a mirrored arrow scrolls back a step, clamped at the start. Both
  arrows are one widget, `_RailArrow`, with the chip's own colours.
- **The tab bar and the sign-in footer were never missing.** The report came
  from Chrome's device toolbar at 440×956 with DevTools docked below: the
  emulated device was taller than the space left for it, so the bottom
  ~100 px — the tab bar on Home, the footer and the request-access sheet on
  sign-in — sat under the DevTools pane. Opened at 440×956 in a viewport that
  fits, both are where the artboards put them. Recorded here so the next
  reviewer knows what to check before filing it.

## 2. Test decision

The rail test advances to the end and back, asserting each arrow appears and
disappears at its end; the wide-screen case shows neither.
