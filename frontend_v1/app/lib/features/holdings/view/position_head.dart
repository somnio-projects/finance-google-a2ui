import 'package:finance_app/theme/holdings_tokens.dart';
import 'package:finance_app/theme/home_tokens.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';

/// The collapsed row's content: ticker badge, name and caption, value and
/// the unrealised result — or, for cash, the day move in the muted tone.
class PositionHead extends StatelessWidget {
  /// Creates the head.
  const PositionHead({required this.row, required this.isCash, super.key});

  /// One entry of `positions[]`.
  final ViewPayload row;

  /// Whether the row is the settlement fund.
  final bool isCash;

  @override
  Widget build(BuildContext context) {
    final tokens = HomeTokens.of(context);
    final holdings = HoldingsTokens.of(context);
    final unrealizedTrend = isCash ? 'flat' : row.text('unrealized.trend');
    final tone = switch (unrealizedTrend) {
      'up' => tokens.gain,
      'down' => tokens.loss,
      _ => tokens.muted,
    };
    final glyph = switch (unrealizedTrend) {
      'up' => '▲',
      'down' => '▼',
      _ => '—',
    };
    final secondLine = isCash
        ? '$glyph ${row.text('day.display')}'
        : '$glyph ${row.text('unrealized.amount.display')} '
              '(${row.text('unrealized.percent.display')})';
    return Row(
      children: <Widget>[
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isCash ? holdings.cashBadge : tokens.ticker,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            row.text('symbol'),
            style: TextStyle(
              fontSize: isCash ? 11 : 12,
              fontWeight: FontWeight.w500,
              color: isCash ? holdings.cashBadgeText : tokens.tickerText,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                row.text('name'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: tokens.text,
                ),
              ),
              Text(
                row.text('detail'),
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
              row.text('value.display'),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: tokens.text,
              ),
            ),
            Text(
              secondLine,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isCash ? FontWeight.w400 : FontWeight.w500,
                color: tone,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
