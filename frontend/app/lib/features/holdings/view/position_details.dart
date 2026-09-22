import 'package:finance_app/features/holdings/view/position_ask.dart';
import 'package:finance_app/theme/holdings_tokens.dart';
import 'package:finance_app/theme/home_tokens.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';

/// The expanded body: `Day` · `Price` · `Weight` tiles and the hand-off.
class PositionDetails extends StatelessWidget {
  /// Creates the details.
  const PositionDetails({required this.row, required this.askLabel, super.key});

  /// One entry of `positions[]`.
  final ViewPayload row;

  /// The hand-off's caption.
  final String askLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = HomeTokens.of(context);
    final dayTone = switch (row.text('day_trend')) {
      'up' => tokens.gain,
      'down' => tokens.loss,
      _ => tokens.muted,
    };
    final dayGlyph = switch (row.text('day_trend')) {
      'up' => '▲',
      'down' => '▼',
      _ => '—',
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: tokens.rowDivider)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(15, 12, 15, 14),
        child: Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                _Stat(
                  label: 'Day',
                  value: '$dayGlyph ${row.text('day.display')}',
                  tone: dayTone,
                ),
                const SizedBox(width: 8),
                _Stat(
                  label: 'Price',
                  value: row.text('price.display'),
                  tone: tokens.text,
                ),
                const SizedBox(width: 8),
                _Stat(
                  label: 'Weight',
                  value: row.text('weight.display'),
                  tone: tokens.text,
                ),
              ],
            ),
            const SizedBox(height: 10),
            PositionAsk(label: askLabel, question: row.text('ask.text')),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.tone});

  final String label;
  final String value;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final tokens = HomeTokens.of(context);
    final holdings = HoldingsTokens.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        decoration: BoxDecoration(
          color: holdings.statTile,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(label, style: TextStyle(fontSize: 10.5, color: tokens.muted)),
            Text(
              value,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: tone,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
