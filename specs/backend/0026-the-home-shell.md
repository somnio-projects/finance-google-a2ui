# 0026 — The Home shell

- **Area:** backend + frontend
- **Status:** In progress
- **Ticket:** _unassigned — see 0025 §6_
- **Also:** 0025 (the design portfolio), 0005 (allocation donut), [ADR-K](../../docs/adr/ADR-K-response-shaping.md), [ADR-L](../../docs/adr/ADR-L-client-architecture.md)
- **Owner:** Lautaro Bertuzzi · **Date:** 2026-09-21

## 1. Problem

`Home.dc.html` is the app's first screen and none of it existed: no tab bar,
no greeting, no hero, no sparkline, no range selector, no suggested questions,
no movers. The client had the six catalog components and a vertical list to
put them in. The user's instruction is that the app be **identical** to the
design, and the shell is most of what a person sees.

The rule that the client binds and never computes does not stop at the
catalog's edge. A hero total assembled from three requests on the client is
the arithmetic ADR-K forbids; a greeting chosen by the device clock is the
clock read N-13 forbids. So the shell's data is a projection like any other.

## 2. Measured, not transcribed

Every colour, size and weight below was read out of the rendered page with
`getComputedStyle`, light and dark. Roboto throughout.

| Element | Light | Dark |
|---|---|---|
| page / header / card | `#F7F6FB` / `#FDFBFF` / `#FDFBFF` r20 border `#EAE7F0` | `#0B0C10` / `#0E0F13` / `#15161C` border `#24252D` |
| badge *Simulated portfolio* | bg `#EAE7F5`, dot `#7A5CFF`, text `#4A3F8A` 11.5/500 | bg `#232036`, dot `#B9C0FF`, text `#C9CBFF` |
| hero | label 12.5/400 `#5F6169` · value 40/400 `#1A1B20` · delta 14.5/500 `#12805C` | value `#E5E1E9` · delta `#4ADE9E` |
| sparkline | 350×52, stroke `#12805C` 2px, fill .22→0 | same hue as delta |
| range selector | 350×38 r20 border `#C4C6D0`; selected `#4F5DFF`/white 12.5/500; else `#44464E` | border `#45464F`; selected `#B9C0FF`/`#151A54` |
| donut | 104px, hole 66px; slices `#4F5DFF` `#0F9D8F` `#9AA0AA` `#F0A52E`; centre `Classes` 10/400, `4` 18/500 | `#7A83FF` `#3FC8B8` `#6F7280` `#F5B942` |
| allocation bar | 6px r4, margin-top 16 | — |
| suggested chips | bg `#FDFBFF` border `#C4C6D0` r20 pad 9×14, text 13/400 `#3A2F70` | bg `#15161C` border `#45464F` text `#C9CBFF` |
| movers | ticker chip 38×38 bg `#EAE7F5` r10 text 12/500 `#4A3F8A`; name 14/500; price 12/400 grey; delta 13.5/500 | chip `#232036`/`#C9CBFF` |
| tab bar | bg `#F0EDF7` border-top `#E3E0EA` pad 10/14; pill 60×30 `#DCD8F2` r16; label 11/500 `#3A2F70` else 11/400 `#5F6169` | bg `#131319` border `#24252D`; pill `#2D2A44`; label `#C9CBFF` else `#A4A6B0` |

`#B9C0FF` — the one design colour the earlier audit found missing from the
tokens — is the dark theme's selected range and badge dot. It has a home now.

## 3. The figures were solved into the seed

The Home page states six things about one day: four class-level day changes
(`+0.9 / −0.2 / 0.0 / +1.4`), the portfolio's (`+$3,240.18 (+0.68%)`) to the
cent, and a movers list (`NVDA +4.2%`, `TSLA −2.3%`, `AAPL +1.1%`). Those are
constraints on fourteen `previous_close` values, and they were satisfied
together by a search over 2-dp prices rather than by hand (`market_data.py`).

Two rules the design implies but does not state were needed to make the
movers list come out: a **fund** never appears on it (it lists single names),
and no non-mover single name moves more than the third mover. VOO carries the
residual and moves −4.9 %; it is a fund, so the list never shows it.

**The catalog page and the Home page disagree** on the class day changes
(`+1.2 / −0.3 / 0.0 / +0.6` vs `+0.9 / −0.2 / 0.0 / +1.4`). Home wins: it is
the screen being built, and the catalog page's figures are gallery data by the
same reasoning as 0025 OD-7.

## 4. Rulings

- **OD-1 — the persona is seed data.** *Alex Chen*, *A*, *Simulated
  portfolio* are not derivable from a token subject and must read the same on
  every screen. `domain/persona.py`, one record, deliberately fake.
- **OD-2 — `group_by` is a declared option of `holdings.allocation.v1`**, with
  `holding | asset_class | sector`, semantic row order, and no `top_n`/`Other`
  folding for the grouped forms — *Cash* is the row every reader looks for.
  Every row gains a signed day change and a trend; the payload gains the
  centre count and the all-time gain; a `headline` option turns the gain block
  off for the Home card, which draws the donut under the shell's own hero.
- **OD-3 — one value series.** `domain/portfolio_history.value_series` is the
  sum of every holding at each day's generated price; cash is carried flat.
  Yesterday's generated price **is** the reference's `previous_close`, so the
  last step of the sparkline equals the day change drawn beside it.
- **OD-4 — movers are single names from the whole reference.** The design
  lists TSLA, which the portfolio does not hold. `MarketAsset.is_fund` is what
  keeps ETFs out.
- **OD-5 — the range changes the delta's period, not the sparkline.** The
  design's own loading state reads *"Loading last 30 days…"*; the sparkline is
  always thirty points. `1d` compares to the close; the rest read the history.
- **OD-6 — the three suggested questions are server-written** and each maps
  to a flow the demo has (A, B, C). `HISTORY_DAYS` rises to 400 so `1y` has a
  base.

- **OD-7 — the centre counts the groups, not the slices.** `center.count` is
  the number of groups the ring is drawn over — fourteen holdings, four
  classes, six sectors — even when `top_n` folds most of them into *Other*;
  the hole says what the portfolio holds, not how many arcs fit. `group_by`
  is a payload field named exactly as the option that sets it, so the
  generated contract lists it as the component's one editable field, on
  purpose: a toggle between the three groupings is a legitimate input. Where
  the payload carries `total_gain`, the header prints it where the total's
  caption would go (the catalog card); with `headline=false` the card draws no
  header at all and the shell's own title stands in.

## 5. Test decision

Every figure the page prints is asserted **as a literal** against the design
— `+$3,240.18`, `+0.68%`, `62% · $299,407 · +0.9%`, `NVDA +4.2%` — the pattern
`test_component_names.py` set. The greeting is asserted at three hours so the
clock provably is not read. The frontend's shell tests pump the snapshot
example and assert the same strings appear verbatim.
