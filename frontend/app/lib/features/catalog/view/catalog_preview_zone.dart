import 'package:finance_app/features/catalog/bloc/catalog_detail_bloc.dart';
import 'package:finance_app/features/catalog/preview_states.dart';
import 'package:finance_app/features/catalog/view/catalog_state_preview.dart';
import 'package:finance_app/features/catalog/view/catalog_zone_label.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';

/// Zone 1: the label row, then one state card per render — a live render at
/// full width, the loading and absent notes in pairs (spec 0013 OD-5).
class CatalogPreviewZone extends StatelessWidget {
  /// Creates the zone.
  const CatalogPreviewZone({
    required this.entry,
    required this.renders,
    super.key,
  });

  /// The zone's words.
  static const String label = 'Zone 1 · Live preview';

  /// The gap between cards, both ways.
  static const double gap = 14;

  /// The page's entry.
  final CatalogEntry entry;

  /// The renders, in the page's order.
  final List<PreviewRender> renders;

  /// Whether [render] draws a real component rather than a note or skeleton.
  static bool _isLive(PreviewRender render) => switch (render.state.kind) {
    PreviewKind.loading || PreviewKind.absent => false,
    _ => true,
  };

  @override
  Widget build(BuildContext context) {
    final cards = <Widget>[
      for (final render in renders)
        CatalogStateCard(
          label: render.state.label,
          child: CatalogStatePreview(render: render, entry: entry),
        ),
    ];
    // A card that renders a real component takes the whole column: the
    // design pairs its mock states at ~290 px, and a real table or ticket
    // needs more than that. Only the loading and absent cards pair up.
    final rows = <Widget>[];
    for (var index = 0; index < cards.length; index++) {
      if (_isLive(renders[index])) {
        rows.add(cards[index]);
        continue;
      }
      final pairable = index + 1 < cards.length && !_isLive(renders[index + 1]);
      rows.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(child: cards[index]),
            const SizedBox(width: gap),
            Expanded(
              child: pairable ? cards[index + 1] : const SizedBox.shrink(),
            ),
          ],
        ),
      );
      if (pairable) index++;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const CatalogZoneLabel(label, simulated: true),
        for (final row in rows) ...<Widget>[const SizedBox(height: gap), row],
      ],
    );
  }
}
