# 0010 — Both themes, from inside the app

- **Area:** frontend
- **Status:** In progress
- **Ticket:** _unassigned — no GGU number exists for this yet; none is invented here_
- **Also:** [`frontend/0008`](0008-sign-in.md) (the sign-in screen), [backend/0026](../backend/0026-the-home-shell.md) §2 (the measured palettes), [ADR-L](../../docs/adr/ADR-L-client-architecture.md)
- **Owner:** Lautaro Bertuzzi · **Date:** 2026-09-21

## 1. Problem

Every artboard in the design bundle is drawn twice — `L1 Light` and `D1
Dark` — and every token file in `app/lib/theme/` already carries both
palettes, measured. Yet the app only ever showed the one the device asked
for: `MaterialApp.router` had `theme` and `darkTheme` and no `themeMode`, so
a reviewer holding a light laptop could not see the dark screens the designer
drew without changing the operating system. The instruction is that both
versions be **available on every screen**.

## 2. What ships

- `ThemeModeController`, a `ValueNotifier<ThemeMode>` starting on `system`,
  and `ThemeModeScope`, an `InheritedNotifier` that hands it down the tree.
  `FinanceApp` owns one and rebuilds `MaterialApp.router` with its value.
- Two entry points, one per side of the door: a quiet round toggle in the
  sign-in screen's top-right corner, and an `Appearance · System | Light |
  Dark` row in the avatar's session sheet, which every tab reaches from Home.
  The choice is app-wide: Holdings, Activity and the Assistant re-theme with
  the sheet still open.

## 3. Rulings

- **OD-1 — a scope, not a provider.** The sign-in screen sits outside the
  shell and the sheet is a route of its own; an `InheritedNotifier` reaches
  both from `FinanceApp` without threading a parameter through pages, and
  `maybeOf` lets a widget pumped alone draw nothing rather than throw.
- **OD-2 — the toggle offers the opposite of what is showing.** It reads
  `Theme.of(context).brightness`, not the controller: from `system` on a dark
  device the button says *light*, and the first tap makes the choice explicit.
- **OD-3 — not persisted, on purpose, for now.** The app has no per-device
  storage seam yet (the session is the identity provider's); adding
  `localStorage` for one preference is a dependency decision for its own spec.
  The default is the device setting, so nobody is stranded.
- **OD-4 — no new design chrome on the tabs.** The artboards draw no theme
  control, so none is added to the tab bars; the sheet and the sign-in corner
  are the two places the design leaves room.

## 4. Test decision

Unit: the controller's default, `select`, notification and labels; the scope
absent and present. Widget: the toggle hidden without a scope, flipping the
controller and its own tooltip; the sheet's row listing the three words,
selecting one and the tree re-theming under it, and hidden without a scope;
the sign-in screen reaching dark before sign-in; `FinanceApp` following the
controller both ways. 100 % line coverage per file, as the gate requires.
