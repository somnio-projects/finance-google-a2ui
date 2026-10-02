import 'package:finance_app/theme/home_tokens.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';

/// *Top movers today*: three rows of ticker tile, name, price and change
/// (spec 0026 OD-4).
///
/// Binds `movers_title` and `movers[].{symbol,name,price.display,
/// change.display,trend}`. The list is the backend's — it includes a name
/// the portfolio does not hold — and its order is the backend's (N-10).
class HomeMovers extends StatelessWidget {
  /// Creates the section.
  const HomeMovers({required this.payload, super.key});

  /// `portfolio.summary.v1`.
  final ViewPayload payload;

  @override
  Widget build(BuildContext context) {
    final tokens = HomeTokens.of(context);
    final rows = payload.rows('movers');
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.card,
        border: Border.all(color: tokens.cardBorder),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
            child: Text(
              payload.text('movers_title'),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: tokens.text,
              ),
            ),
          ),
          for (final row in rows) _MoverRow(row: row),
        ],
      ),
    );
  }
}

class _MoverRow extends StatelessWidget {
  const _MoverRow({required this.row});

  final ViewPayload row;

  @override
  Widget build(BuildContext context) {
    final tokens = HomeTokens.of(context);
    final trend = row.text('trend');
    final tone = trend == 'up'
        ? tokens.gain
        : trend == 'down'
        ? tokens.loss
        : tokens.muted;
    final glyph = trend == 'up'
        ? '▲'
        : trend == 'down'
        ? '▼'
        : '—';
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: tokens.rowDivider)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
        child: Row(
          children: <Widget>[
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tokens.ticker,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                row.text('symbol'),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: tokens.tickerText,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    row.text('name'),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: tokens.text,
                    ),
                  ),
                  Text(
                    row.text('price.display'),
                    style: TextStyle(fontSize: 12, color: tokens.muted),
                  ),
                ],
              ),
            ),
            Text(
              '$glyph ${row.text('change.display')}',
              style: TextStyle(
                fontSize: 13.5,
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
