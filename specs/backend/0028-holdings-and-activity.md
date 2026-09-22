# 0028 — The Holdings and Activity tabs

- **Area:** backend + frontend
- **Status:** In progress
- **Ticket:** _unassigned — no GGU number exists for this yet; none is invented here (see 0025 §6)_
- **Also:** 0025 (the design portfolio), 0026 (the Home shell, `holdings.allocation.v1` grouped), [ADR-K](../../docs/adr/ADR-K-response-shaping.md), [ADR-E](../../docs/adr/ADR-E-money-representation.md)
- **Owner:** Lautaro Bertuzzi · **Date:** 2026-09-21

## 1. Problem

Two of the four tabs had nothing behind them. `Holdings.dc.html`: *"Expanded
Holdings & Allocation catalog component (By class / By sector toggle) +
SegmentedButton + data-dense position list. Each row carries a thin
left-border accent encoding today's move. NVDA shown in its pressed/expanded
state revealing the 'Ask the assistant' hand-off. Tabular figures
throughout."* `Activity.dc.html`: *"Transaction history as a grouped,
date-sectioned timeline. Filter chips scope by type; each row carries a type
icon, price/quantity subtitle, and a right-aligned amount (buys neutral,
dividends green +, sells colored by realized P/L). Sell rows add a tax-lot
badge — amber ST, teal LT — seeding the concept Flow B expands."*

Both screens are made of words and figures the client must not compute or
spell (ADR-K, N-9), so both are projections.

## 2. What ships

- **`holdings.positions.v1`** (component `PositionList`): title, the total
  with its all-time unrealised gain (`+$61,204 · +14.5% · all-time
  unrealized`), the hand-off's caption, and one row per position — `90 sh ·
  avg $826.67`, value, unrealised `+$34,019 (+45.7%)`, today's `+4.2%`, the
  price, the weight `22.5%`, whether it is cash, and the question the hand-off
  sends the assistant. Options: `DisplayOptions` + `sort`
  (`value_desc | value_asc | label`); cash is pinned last whenever value
  decides. The tab's allocation card is `holdings.allocation.v1` with
  `group_by` and `headline=false` (spec 0026).
- **`activity.timeline.v1`** (component `ActivityTimeline`): the ledger as
  dated sections — `TODAY`, `THIS WEEK`, then `SEPTEMBER 2026` and so on —
  each row with its kind, a title (`Bought 60 NVDA`, `Dividend — VOO`,
  `Deposit — Bank transfer`), a caption (`60 sh @ $760.00 · Sep 16`,
  `$1.62/sh · 85 sh · qualified`, `Chase ••4021 · Wed`), a signed amount and
  its tone, a badge, and for a sell the realised line (`+$1,738 realized`)
  with its term badge (`ST gain`). Options: `DisplayOptions` + `kind`
  (`all | buy | sell | dividend | deposit`) + `limit` (1..200).
- **The ledger grows two kinds and a memo.** `TransactionType` gains
  `dividend` and `deposit`; `Transaction.memo` (nullable, 64) carries the
  server-written words beside a row; migration `0007` adds the column. Six
  seeded rows: dividends on VOO, MSFT, AAPL and JNJ, a bank deposit and a
  payroll deposit, placed relative to `as_of` so the sections come out as the
  design draws them.

## 3. Rulings

- **OD-1 — the position list is a page, not a catalog card**, like the Home
  hero: named by us (`PositionList`), registered with fitness 0 so the
  selection rule never volunteers it.
- **OD-2 — the design's average costs are not this seed's for two rows.**
  0025 OD-9 split NVDA and AAPL into two lots at two costs so the lot methods
  can disagree; the list therefore prints `avg $826.67` and `avg $135.40`
  where the design prints `$760.00` and `$155.40`. Every other figure on the
  row is the design's.
- **OD-3 — what a past sale realised is read from the ledger**, oldest buys
  first until the sold quantity is covered; long-term only when every consumed
  buy was held over a year. Each sale is walked on its own — a second sale of
  the same symbol would share the first one's buys. The simulation has one
  sale; the simplification is recorded so it is not mistaken for a rule.
- **OD-4 — month and weekday names are a vocabulary, in `core/calendar_words`.**
  `dates.py` prints digits on purpose (a component's dates are figures); a
  timeline's headings are words, and the design writes them. Three locales,
  keyed like the money formats, and a test compares the key sets.
- **OD-5 — the design's activity is gallery data.** *Bought 12 NVDA today*
  and *Sold 40 PYPL* contradict the lots (the portfolio holds 90 NVDA bought
  a year ago and has never sold PYPL). The timeline is the seeded ledger:
  the buys that built the positions, the one VOO sale, and the income and
  deposits above. Same shape, honest rows.
- **OD-6 — a buy prints with a hyphen minus (`-$45,600.00`)**, as every
  signed figure in this service does; the design's `−` (U+2212) is not
  adopted, because one glyph for a negative across the app matters more than
  matching one artboard's typography.
- **OD-7 — the segmented `By position / By asset class` and the `By asset
  class / By sector` toggle are client chrome**, like the range selector: the
  first switches which list the tab shows (positions, or the class rows of
  `holdings.allocation.v1`), the second sets `group_by`.

## 4. Test decision

Unit: `realized_of` over hand-made ledgers (oldest-first consumption, the
term rule, an uncoverable sale); the calendar vocabulary per locale; both
projections over the seeded portfolio with literal expectations for every
string the client binds, the filters, the limit, the sort orders, the locale,
the surfaces and the fitness. The catalog is regenerated and both artefacts
committed. Integration: the ledger round-trips through PostgreSQL with the
memo (the existing repository suite, over the new seed).
