import 'package:finance_app/features/activity/view/activity_term_badge.dart';
import 'package:finance_app/theme/activity_tokens.dart';
import 'package:finance_app/theme/home_tokens.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';

/// One row of the timeline: the kind's icon tile, the title and caption, the
/// amount and its badge — and for a sell, the term badge and the realised
/// line (spec frontend/0009 §2).
class ActivityEntryTile extends StatelessWidget {
  /// Creates the tile.
  const ActivityEntryTile({required this.entry, super.key});

  /// The glyph the design draws per kind.
  static const Map<String, String> glyphs = <String, String>{
    'buy': '↓',
    'sell': '↑',
    'dividend': r'$',
    'deposit': '+',
  };

  /// One entry of `groups[].entries[]`.
  final ViewPayload entry;

  @override
  Widget build(BuildContext context) {
    final tokens = HomeTokens.of(context);
    final activity = ActivityTokens.of(context);
    final kind = entry.text('kind');
    final (tile, glyph) = activity.tileFor(kind);
    final tone = switch (entry.text('tone')) {
      'up' => tokens.gain,
      'down' => tokens.loss,
      _ => tokens.text,
    };
    final term = entry.optionalText('term.label');
    final realized = entry.optionalText('realized.text');
    return Container(
      padding: const EdgeInsets.fromLTRB(15, 13, 15, 13),
      decoration: BoxDecoration(
        color: tokens.card,
        border: Border.all(color: tokens.cardBorder),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: tile,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              glyphs[kind] ?? '·',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w500,
                color: glyph,
              ),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  entry.text('title'),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: tokens.text,
                  ),
                ),
                const SizedBox(height: 2),
                // One line, badge inline — the design hugs `ST gain` to the
                // caption. As a span the line ellipsizes when a narrow
                // viewport cannot hold both, instead of overflowing.
                Text.rich(
                  TextSpan(
                    children: <InlineSpan>[
                      TextSpan(text: entry.text('detail')),
                      if (term != null) ...<InlineSpan>[
                        const WidgetSpan(child: SizedBox(width: 7)),
                        WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: ActivityTermBadge(
                            label: term,
                            term: entry.text('term.term'),
                          ),
                        ),
                      ],
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11.5, color: tokens.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                entry.text('amount.display'),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: tone,
                ),
              ),
              if (realized != null)
                Text(
                  realized,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: entry.text('realized.trend') == 'down'
                        ? tokens.loss
                        : tokens.gain,
                  ),
                )
              else
                Text(
                  entry.text('badge'),
                  style: TextStyle(fontSize: 11, color: activity.badge),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
