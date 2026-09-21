import 'package:finance_app/charts/chart_palette.dart';
import 'package:finance_app/charts/chart_text.dart';
import 'package:finance_app/charts/waterfall_marks.dart';
import 'package:finance_app/components/attribution_waterfall/attribution_waterfall_model.dart';
import 'package:flutter/material.dart';

/// The card's title row: the caption, and every annotation as a chip.
///
/// **All** annotations are shown, in arrival order. The design shows one —
/// a green "Net" pill — and the contract has no field saying which
/// annotation is the net or which way it points, so picking one by matching
/// `label == 'Net'` would be the client interpreting a server string (N-5)
/// and colouring it would be the client deciding a sign (N-1). The chips are
/// therefore neutral, and `specs/frontend/0002` OD-2 carries the backend
/// field that would let them match the design.
class AttributionWaterfallHeader extends StatelessWidget {
  /// Creates the header.
  const AttributionWaterfallHeader({
    required this.title,
    required this.annotations,
    super.key,
  });

  /// The payload's `title`.
  final String title;

  /// The payload's `annotations`, rendered verbatim and never dropped (N-9).
  final List<AttributionAnnotation> annotations;

  @override
  Widget build(BuildContext context) {
    final palette = ChartPalette.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(child: Text(title, style: ChartText.title(palette.title))),
        const SizedBox(width: 12),
        Flexible(
          child: Wrap(
            alignment: WrapAlignment.end,
            spacing: 6,
            runSpacing: 6,
            children: <Widget>[
              for (final annotation in annotations)
                _Chip(annotation: annotation, palette: palette),
            ],
          ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.annotation, required this.palette});

  final AttributionAnnotation annotation;
  final ChartPalette palette;

  @override
  Widget build(BuildContext context) => DecoratedBox(
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
  );
}

/// What the reader sees after tapping a band.
///
/// The design puts this in a floating dark tooltip with the position's price
/// and share count. Neither figure is in `attribution.waterfall.v1` — the
/// contract carries a bucket's label, its contribution and the running total
/// and nothing else — so this shows those three rather than inventing the
/// rest (N-3). `specs/frontend/0002` OD-3 carries the gap.
class AttributionWaterfallDetail extends StatelessWidget {
  /// Creates the detail strip.
  const AttributionWaterfallDetail({required this.step, super.key});

  /// The selected step.
  final AttributionStep step;

  @override
  Widget build(BuildContext context) {
    final palette = ChartPalette.of(context);
    return Semantics(
      container: true,
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: palette.rule,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(step.label, style: ChartText.title(palette.title)),
              ),
              Text(
                step.valueDisplay,
                style: ChartText.chip(palette.labelFor(step.step.kind)),
              ),
              const SizedBox(width: 12),
              Text(
                step.cumulativeDisplay,
                style: ChartText.chip(palette.mutedLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
