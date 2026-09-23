import 'package:finance_app/features/shell/view/shell_tab_bar.dart';
import 'package:flutter/material.dart';

/// A surface's header band: its fill, the rule under it, and the top
/// safe-area inset it now has to respect.
///
/// **Why this exists.** Every surface in this app used to put its header
/// inside the scrollable — `ListView(children: [header, …rest])` — so the
/// header scrolled away with the content. The TL hit it on Home and on
/// Holdings and asked for the opposite, *"de todas las paginas"*, because
/// this ships to mobile and the header is the anchor the tab bar is at the
/// other end (spec frontend/0021 OD-3, frontend/0024).
///
/// Holding the header out of the scrollable is each surface's own job — a
/// `Column` whose second child is an `Expanded` scrollable — because *what*
/// sits above the fold is the surface's answer. What is **not** the
/// surface's answer is how the band is drawn, and that is here, so six
/// screens cannot each decide it differently.
///
/// **The inset is the half that only matters once the header is pinned.**
/// Nothing in this app applied a *top* safe-area inset: `SafeArea` appears
/// at four bottom edges ([ShellTabBar], the composer, the filter sheet,
/// sign-in) and nowhere at the top. That was survivable while the header
/// scrolled — the status bar overlapped it only at offset 0 — and it is not
/// once the header never moves. The `SafeArea` is **inside** the
/// `DecoratedBox`, exactly as [ShellTabBar] does it at the other end, so the
/// inset strip is painted in the band's own colour rather than showing the
/// page through it.
class PinnedHeader extends StatelessWidget {
  /// Creates the band in [color] around [child].
  const PinnedHeader({
    required this.color,
    required this.child,
    this.border,
    super.key,
  });

  /// The band's fill — the surface's own header token.
  final Color color;

  /// The rule under the band, where the design draws one.
  final BoxBorder? border;

  /// The header itself, with its own padding.
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    // A band is the width of the surface, whatever is in it. Without this
    // the header takes its child's width — a `Column`'s cross axis is
    // `center`, not `stretch` — and a skeleton header, whose child is a
    // 150-point shimmer rather than a `Row`, drew as a floating pill in the
    // middle of the page. Caught by the `holdings_first_run` golden, which
    // is the thing goldens are kept for.
    width: double.infinity,
    decoration: BoxDecoration(color: color, border: border),
    // `Container` and not a bare `DecoratedBox`: a `DecoratedBox` paints a
    // border without reserving room for it, so swapping one in shortened
    // the catalog's bar by the rule's 1 px and moved every row under it up
    // by one. A rule that is drawn occupies space.
    //
    // Top, left and right: a pinned header can meet a notch on three
    // edges. Never the bottom — it is not against the bezel, and the tab
    // bar owns that edge.
    child: SafeArea(bottom: false, child: child),
  );
}
