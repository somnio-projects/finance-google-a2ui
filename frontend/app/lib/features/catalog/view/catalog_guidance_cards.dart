import 'package:finance_app/theme/catalog_tokens.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';

/// The Do / Don't pair under the zones, bound to the entry's `guidance`.
///
/// Where design has written no page the backend serves `null`, and this
/// draws one quiet card saying so rather than a sentence of its own — the
/// same honesty the contract's Markdown keeps (spec backend/0023).
class CatalogGuidanceCards extends StatelessWidget {
  /// Creates the cards for [guidance], which may be null.
  const CatalogGuidanceCards({required this.guidance, super.key});

  /// What the card says when the backend serves no pair.
  static const String none =
      'No design page has been transcribed for this component yet, so the '
      "backend serves no do/don't pair and the prompt above carries none.";

  /// The served pair, or null.
  final CatalogGuidance? guidance;

  @override
  Widget build(BuildContext context) {
    final tokens = CatalogTokens.of(context);
    final zones = tokens.zones;
    final pair = guidance;
    if (pair == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: tokens.card,
          border: Border.all(color: tokens.cardBorder),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          none,
          style: TextStyle(fontSize: 12.5, height: 1.4, color: tokens.quiet),
        ),
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: _Card(
            fill: zones.doCard,
            border: zones.doBorder,
            badge: zones.doBadge,
            badgeText: zones.doBadgeText,
            text: zones.doText,
            strong: zones.doStrong,
            glyph: '✓',
            word: 'Do',
            sentence: pair.useWhen,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _Card(
            fill: zones.dontCard,
            border: zones.dontBorder,
            badge: zones.dontBadge,
            badgeText: zones.dontBadgeText,
            text: zones.dontText,
            strong: zones.dontStrong,
            glyph: '×',
            word: "Don't",
            sentence: pair.avoidWhen,
          ),
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.fill,
    required this.border,
    required this.badge,
    required this.badgeText,
    required this.text,
    required this.strong,
    required this.glyph,
    required this.word,
    required this.sentence,
  });

  final Color fill;
  final Color border;
  final Color badge;
  final Color badgeText;
  final Color text;
  final Color strong;
  final String glyph;
  final String word;
  final String sentence;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: fill,
      border: Border.all(color: border),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: <Widget>[
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: badge, shape: BoxShape.circle),
          child: Text(
            glyph,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: badgeText,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text.rich(
            TextSpan(
              text: word,
              style: TextStyle(fontWeight: FontWeight.w600, color: strong),
              children: <InlineSpan>[
                TextSpan(
                  text: ' — $sentence',
                  style: TextStyle(fontWeight: FontWeight.w400, color: text),
                ),
              ],
            ),
            style: const TextStyle(fontSize: 12.5, height: 1.4),
          ),
        ),
      ],
    ),
  );
}
