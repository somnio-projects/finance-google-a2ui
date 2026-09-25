import 'package:finance_app/charts/chart_palette.dart';
import 'package:finance_app/charts/chart_text.dart';
import 'package:finance_app/components/attribution_waterfall/attribution_waterfall_model.dart';
import 'package:flutter/material.dart';

/// Every annotation the backend attached, as one neutral chip each.
///
/// **All** annotations are shown, in arrival order (N-9). They used to share
/// the header with the title; the design's header carries the net figure
/// instead (GGU-100, restyled by spec frontend/0028 OD-1), so the notes moved
/// under the chart rather than being dropped — spec frontend/0014 OD-2.
///
/// The UI Kit's own card draws no chips, because the frame's example carries
/// no annotations. The backend's does, and a note the payload sends is not
/// the client's to drop (0028 OD-6). The chips stay neutral: nothing in an
/// annotation says which way it points, and colouring one by matching its
/// label would be the client interpreting a server string (N-5).
class AttributionWaterfallNotes extends StatelessWidget {
  /// Creates the row.
  const AttributionWaterfallNotes({required this.annotations, super.key});

  /// The payload's `annotations`, rendered verbatim and never dropped.
  final List<AttributionAnnotation> annotations;

  @override
  Widget build(BuildContext context) {
    final palette = ChartPalette.of(context);
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: <Widget>[
        for (final annotation in annotations)
          DecoratedBox(
            decoration: BoxDecoration(
              color: palette.rule,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              child: Text(
                '${annotation.label} ${annotation.text}',
                style: ChartText.chip(palette.mutedLabel),
              ),
            ),
          ),
      ],
    );
  }
}
