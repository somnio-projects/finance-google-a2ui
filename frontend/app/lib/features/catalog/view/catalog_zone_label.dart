import 'package:finance_app/features/catalog/view/catalog_pill.dart';
import 'package:finance_app/theme/catalog_tokens.dart';
import 'package:flutter/material.dart';

/// A zone's heading row: the subtag in the accent, a hairline to the edge,
/// and — on Zone 1 — the `Simulated data` mark.
class CatalogZoneLabel extends StatelessWidget {
  /// Creates the row for [label].
  const CatalogZoneLabel(this.label, {this.simulated = false, super.key});

  /// The mark's words.
  static const String simulatedLabel = 'Simulated data';

  /// The zone's words, e.g. `Zone 1 · Live preview`.
  final String label;

  /// Whether to end the row with the simulation mark.
  final bool simulated;

  @override
  Widget build(BuildContext context) {
    final tokens = CatalogTokens.of(context);
    return Row(
      children: <Widget>[
        // Flexible: the zone's own name is the part that may ellipsise. The
        // rule beside it is already `Expanded` and collapses to nothing, so
        // once it had, the fixed parts still exceeded a narrow row — which
        // is what happened the moment these pages moved inside the shell
        // and lost the tab bar's width (spec frontend/0021 OD-3).
        Flexible(child: CatalogSubtag(label, color: tokens.accent)),
        const SizedBox(width: 8),
        Expanded(child: Container(height: 1, color: tokens.rule)),
        if (simulated) ...<Widget>[
          const SizedBox(width: 8),
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: tokens.accentDot,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            simulatedLabel,
            style: TextStyle(fontSize: 10.5, color: tokens.quiet),
          ),
        ],
      ],
    );
  }
}

/// A Zone 1 state card: the state's label as a quiet subtag over its body.
class CatalogStateCard extends StatelessWidget {
  /// Creates the card.
  const CatalogStateCard({required this.label, required this.child, super.key});

  /// The state's caption, e.g. `Selected · onSegmentTap`.
  final String label;

  /// The rendered state.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = CatalogTokens.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      decoration: BoxDecoration(
        color: tokens.card,
        border: Border.all(color: tokens.cardBorder),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          CatalogSubtag(label, color: tokens.quiet),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}
