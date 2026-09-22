import 'package:finance_app/theme/catalog_tokens.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// The catalog's way out, in the top bar's leading slot.
///
/// Its own file because `catalog_top_bar.dart` is at the 150-line budget,
/// and because the reason it exists deserves to be findable: the catalog's
/// two routes sit OUTSIDE the `StatefulShellRoute`, so neither inherits the
/// tab bar. That is deliberate — a documentation surface is not a tab — but
/// it left both pages with no way back into the app. On the web the
/// browser's back button hides it; in the app it is a dead end.
///
/// [destination] rather than `pop()`: the catalog is reachable from the Home
/// chip and from a Holdings card, so what is underneath on the stack is not
/// always what a reader means by "back". The caller names where back goes,
/// and on a detail page that is the same place the crumb names, so the two
/// controls cannot disagree.
class CatalogBackControl extends StatelessWidget {
  /// Creates the control.
  const CatalogBackControl({
    required this.label,
    required this.destination,
    super.key,
  });

  /// What a screen reader announces, and the tooltip's words.
  final String label;

  /// The route this returns to.
  final String destination;

  @override
  Widget build(BuildContext context) {
    final tokens = CatalogTokens.of(context);
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        // `GestureDetector`, not `InkResponse`: this bar is a `Container`
        // with no `Material` ancestor, and the rest of the app's own tap
        // targets — the crumb beside this, `PositionAsk` — are gesture
        // detectors too. An ink ripple here would be the only one on a
        // documentation surface.
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => context.go(destination),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Icon(Icons.arrow_back, size: 18, color: tokens.text),
          ),
        ),
      ),
    );
  }
}
