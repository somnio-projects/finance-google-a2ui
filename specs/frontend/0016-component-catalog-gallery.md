# 0016 — The component catalog, as the gallery pages frame it

- **Area:** frontend (+ backend/0034 for the two served facts)
- **Status:** In progress
- **Ticket:** _unassigned — no GGU number exists for this yet; none is invented here. The per-component gaps it surfaces are GGU-101..GGU-104._
- **Also:** [backend/0034](../backend/0034-the-catalog-serves-the-gallery.md), [backend/0023](../backend/0023-catalog-serves-the-client.md) (naming, guidance), [backend/0024](../backend/0024-contract-serves-the-designs.md), [frontend/0009](0009-holdings-and-activity-tabs.md) OD-5 (the `Catalog` chip), [client/0003](../client/0003-client-backend-contract.md) N-3/N-6/N-7/N-9/N-10, [ADR-L](../../docs/adr/ADR-L-client-architecture.md) D-3
- **Owner:** Lautaro Bertuzzi · **Date:** 2026-09-22

## 1. Problem

`/catalog` was `PortfolioViewsPage`: an `AppBar('Portfolio')` over a
`ListView` of every registered component rendered against the live
portfolio. It was the Holdings tab before 0009 moved the tabs to their own
frames, and it matched none of the seven catalog artboards: no doc top bar,
no header, no token legend, no cards, no detail page, no schema, no prompt
fragment. `Catalog_Index.dc.html` asks for *"six cards, each a live thumbnail
linking to its component detail page"*, and each `Catalog_<Component>` page
for three zones — *live preview · A2UI schema · the system-prompt fragment
that teaches the agent when to reach for it* — light and dark at 1024.

Two of those zones had nothing to bind. `GET /v1/views` served the example,
the options schema, the actions and the do/don't pair, but not the field
inventory (only the generated snapshot had it) and not the text the prompt
actually carries for a view (only `prompt.py` composed it, for the model).
A gallery drawn from anything else would have been a second declaration of
the contract — the defect 0023 exists for. Backend/0034 adds both to the
served entry; this spec binds them.

## 2. Measured, not transcribed

Read out of the seven pages' inline `style` attributes, light and dark. All
in `CatalogTokens` (`theme/catalog_tokens.dart`, palettes beside it), pinned
by `catalog_tokens_test.dart`; the legend's gain and loss are pinned to
`HomeTokens` so the caption cannot name a palette the components do not draw.

| Element | Light | Dark |
|---|---|---|
| board · top bar | `#F4F2F8` · bar `#FDFBFF` border `#EAE7F0`, pad 14 32; 26×26 r8 gradient `#4F5DFF→#7A5CFF`; title 14/500 `#1A1B20`; crumb mono 11 `#5F6169` (index) / `#8A8D96` with the component in the accent (detail) | `#0B0C10` · `#0E0F13`/`#24252D`; title `#E5E1E9`; crumb `#A4A6B0` |
| header | eyebrow mono 11/500 `#4F5DFF` .06em; h2 30/1.15 −0.5 `#1A1B20` (27 on a detail page); lede 14/1.6 `#44464E`; pills mono 11/500 `#3A2F70` on `#EAE7F5` r8 pad 5×10; component pill `#0C6A60` on `#DCEFEC` | eyebrow `#B9C0FF`; h2 `#E5E1E9`; lede `#C9CBD4`; pills `#C9CBFF` on `#232036`; component pill `#5FD6C8` on `#17302C` |
| legend | card `#FDFBFF` border `#EAE7F0` r16 pad 16 18, gap 26; `Design tokens` 12/500 with a 10 px `#4F5DFF` swatch; items 12.5 `#44464E` with 11 px swatches gain `#12805C`, loss `#C0362C`, short-term `#F0A52E`, long-term `#0F9D8F`; `Simulated data` 11.5 `#8A8D96` with a 6 px `#7A5CFF` dot | card `#15161C`/`#24252D`; swatch `#7A83FF`; items `#C9CBD4`; gain `#4ADE9E`, loss `#FF6B5E`, short `#FFBF5C`, long `#3FC8B8`; dot `#B9C0FF` |
| card | 3 columns gap 16; r20, `#FDFBFF` border `#EAE7F0`; well 118 tall `#F5F3FB` bottom hairline `#EEE9F4` pad 14 16; body pad 15 18 16: title 15/500, text 12.5/1.5 `#5F6169`, mono badge 10.5/500 `#5F6169` on `#EFEAF5` r7 pad 4×8, `View schema →` 12/500 `#4F5DFF` | `#15161C`/`#24252D`; well `#101017`/`#24252D`; text `#A4A6B0`; badge `#C9CBD4` on `#232036`; link `#B9C0FF` |
| zones | label `.subtag` mono 10/600 upper .08em in the accent + 1 px rule `#E6E2EF`; grid 1.55fr/1fr gap 20; state card r16 pad 16 18 14 with the label in `#8A8D96` | rule `#24252D` |
| Zone 2 | panel `#0D1017` r14 pad 16 18, mono 11.5/1.65 `#C9D1D9`; key `#9CDCFE`, string `#CE9178`, type `#4EC9B0`, comment `#6A9955` | `#000` border `#24252D` |
| Zone 3 | panel `#F7F4FC` border `#E6E0F2`, left 3 px `#7A5CFF`, r12 pad 14 16; `Injected into system prompt` subtag `#7A5CFF`; text 12.5/1.65 `#3A3550` | `#181528`/`#2C2842`; subtag `#B9A5FF`; text `#C9C6DE` |
| Do / Don't | `#E3F3EC`/`#C4E6D5`, 22 px badge `#12805C` white `✓`, text `#0C5A41`; `#FBE9E7`/`#F2CCC7`, badge `#C0362C` `×`, text `#8F2A22`; r12 pad 12 16, gap 14, 22 below the zones | `#12291F`/`#1F4536`, badge `#4ADE9E` on `#06301F`, text `#8FE6BF` strong `#C9F5E0`; `#2A1512`/`#4A231E`, badge `#FF6B5E` on `#3A0D09`, text `#F5A89F` strong `#FFC9C2` |
| skeleton | shimmer `rgba(120,120,140,.24)`, flat bar `#E6E2EF` | `rgba(160,160,190,.20)`, `#22232B` |

## 3. Rulings

- **OD-1 — the index is the served catalog crossed with the registry.** A
  card is drawn for every entry of `GET /v1/views` whose id a component
  registered; the ids the backend serves without a component in this build
  are named under the grid, never drawn as a broken thumbnail. So the six
  cards are six because the backend serves nine views and this build renders
  six — not because anything says "six" (the design's lede does; ours does
  not). The thumbnail is the **real component** bound to the entry's
  `example`, laid out at 380 and scaled into the 118 px well behind an
  `IgnorePointer`; a drawing of the component would drift the day it changed.
- **OD-2 — the words on a card are the entry's.** The design hand-writes a
  title (*Attribution waterfall chart*) and a one-liner per card; the backend
  serves neither. The title is `component` — the string this client registers
  against — the description is `summary`, the badge is `id`. The same three
  head the detail page, whose third pill is the component in teal.
- **OD-3 — chrome that would state a fact the backend does not is dropped.**
  The lede loses its count and its *ADK*; the `A2UI v1.0` pill is not shown
  because nothing served here states a protocol version; `Catalog v1` (the
  `/v1` prefix) and `Apache 2.0` (the LICENSE) stay.
- **OD-4 — Zone 2 prints the inventory the backend serves, not the design's
  schema.** The pages show a hand-written `props` block with names the
  backend never emits (`weightPct`, `onSliceTap`, `betterWhen`). The panel
  binds `component`, `id`, `endpoints`, every `fields[]` row (path, type,
  presence, binding, state, input) and every `actions[]` declaration, in the
  design's syntax colours. Punctuation is the only thing the client adds.
- **OD-5 — Zone 1 draws a state only where a payload can produce it.**
  Every page opens on the example. A state the design lists is then one of:
  a **re-render** by the backend with a declared option, requested alone
  (N-7 — `previewStatesFor` is pinned against the snapshot's
  `options_schema`, and the bloc refuses an undeclared option before spending
  a request); the waterfall's own **selection**, opened on the first bucket
  through the component's binding; the ticket **recomputed** with `size: 2`,
  its changed figures marked by the same comparison the Order ticket screen
  uses over two backend payloads; the **skeleton** the Assistant draws while
  a surface composes (0011 OD-2); or **absent**, a card whose only content is
  the sentence saying why — never a payload this client made up (N-3). A
  live card takes the full column; only skeleton and absent cards pair up,
  because a real table needs more than the ~290 px the design's mocks fit in.
- **OD-6 — Zone 3 is the prompt, verbatim.** The panel shows the entry's
  `prompt`: the lines `presentation/prompt.py` composes for that view, which
  is what the model reads. Where design wrote no page the backend serves no
  `guidance`, the fragment carries no pair, and one quiet card says so in
  place of Do / Don't. The three components in that state, and the states
  the contract cannot produce, are the gaps: `HoldingsSummary` (GGU-101),
  `OrderTicket` (GGU-102: the over-cash validation — no cash constraint
  exists), `RiskPayoffChart` (GGU-103: hold-vs-after-sell — one series per
  render), `TaxLotTable`'s empty state (GGU-104: any quantity consumes a lot),
  and the 2-scenario variant of `ScenarioComparison` (`methods` is a repeated
  parameter this client's single-valued option map cannot send).
- **OD-7 — the catalog stays on `ViewsRepository`.** `fetchCatalog()` is a
  method of the one repository the composition root builds, revalidated by
  `ETag` and forgotten on sign-out like the envelopes; a second repository
  would have meant editing `bootstrap.dart`, `FinanceApp`, the layering test
  and every harness for one read. The cache key moved to `viewCacheKey` to
  keep the file inside the budget.
- **OD-8 — the detail route carries the id through.** `/catalog/:view` hands
  the segment to the bloc untouched; the catalog decides whether it names a
  view and the page shows the answer either way (N-6).

## 4. Test decision

Package: `CatalogEntry`, `CatalogField`, `CatalogAction`, `CatalogGuidance`,
`ViewCatalog` bind every served cell and name the path of a missing one;
`fetchCatalog` reads `/v1/views`, revalidates with the tag, resolves a 304 to
the cached copy, refuses a 304 with nothing cached and passes transport and
contract failures through; `clearCache` forgets the catalog. Bloc: the index
loads or fails with its code; the detail bloc renders the states that name
declared options alone, refuses the undeclared one without a request,
records a refused re-render on its card, fails the page when the catalog
fails or serves no such view. States: every option every state sends is
declared by the snapshot; every absent or loading state carries its
sentence; the example comes first. Widget: the view spins, shows the
backend's sentence, draws one card per served-and-registered view and names
the rest; a card binds component, summary, id and link and opens the detail
route; the thumbnail is the real component at 380 wide in a 118 well; the
grid picks 3/2/1 columns and stretches a row; header, legend, top bar and
zone labels say their words in both themes; Zone 2 prints every field path
and the action; Zone 3 shows the fragment verbatim; the pair or its absence;
every state kind renders what OD-5 says; the detail view lays the zones side
by side at 1024 and stacks them at 600. Router: every registered component
has a card on `/catalog`, against the real registry and the real snapshot.
`CatalogTokens` pinned light and dark. 100 % line coverage per file, as the
gate requires. Both themes were **not** verified by eye in a browser in this
run — no stack was available to the worktree; the coordinator's manual run
at integration is the field for that.
