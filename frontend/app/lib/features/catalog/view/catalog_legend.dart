import 'package:finance_app/theme/catalog_tokens.dart';
import 'package:flutter/material.dart';

/// The shared token legend: the four semantic swatches every page uses and
/// the `Simulated data` mark. The words are chrome; the colours are the
/// tokens the components draw, pinned by `catalog_tokens_test.dart`.
class CatalogLegend extends StatelessWidget {
  /// Creates the legend.
  const CatalogLegend({super.key});

  /// The legend's own title.
  static const String title = 'Design tokens';

  /// The simulation mark's words.
  static const String simulated = 'Simulated data';

  @override
  Widget build(BuildContext context) {
    final tokens = CatalogTokens.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: tokens.card,
        border: Border.all(color: tokens.cardBorder),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Wrap(
        spacing: 26,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          _Item(
            swatch: _Swatch(color: tokens.tokenSwatch, size: 10),
            label: title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: tokens.text,
            ),
          ),
          _Item(
            swatch: _Swatch(color: tokens.gain, size: 11),
            label: 'Gain',
            style: TextStyle(fontSize: 12.5, color: tokens.body),
            arrow: '▲',
            arrowColor: tokens.gain,
          ),
          _Item(
            swatch: _Swatch(color: tokens.loss, size: 11),
            label: 'Loss',
            style: TextStyle(fontSize: 12.5, color: tokens.body),
            arrow: '▼',
            arrowColor: tokens.loss,
          ),
          _Item(
            swatch: _Swatch(color: tokens.shortTerm, size: 11),
            label: 'Short-term',
            style: TextStyle(fontSize: 12.5, color: tokens.body),
          ),
          _Item(
            swatch: _Swatch(color: tokens.longTerm, size: 11),
            label: 'Long-term',
            style: TextStyle(fontSize: 12.5, color: tokens.body),
          ),
          _Item(
            swatch: _Swatch(color: tokens.accentDot, size: 6, round: true),
            label: simulated,
            style: TextStyle(fontSize: 11.5, color: tokens.quiet),
          ),
        ],
      ),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({
    required this.swatch,
    required this.label,
    required this.style,
    this.arrow,
    this.arrowColor,
  });

  final Widget swatch;
  final String label;
  final TextStyle style;
  final String? arrow;
  final Color? arrowColor;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      swatch,
      const SizedBox(width: 7),
      Text(label, style: style),
      if (arrow case final String glyph) ...<Widget>[
        const SizedBox(width: 4),
        Text(
          glyph,
          style: style.copyWith(color: arrowColor, fontWeight: FontWeight.w500),
        ),
      ],
    ],
  );
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.color, required this.size, this.round = false});

  final Color color;
  final double size;
  final bool round;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: color,
      shape: round ? BoxShape.circle : BoxShape.rectangle,
      borderRadius: round ? null : BorderRadius.circular(3),
    ),
  );
}
