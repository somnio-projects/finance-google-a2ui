import 'package:finance_app/charts/allocation_palette.dart';
import 'package:finance_app/theme/holdings_tokens.dart';
import 'package:finance_app/theme/home_tokens.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';

/// `By asset class`: one row per slice of the allocation card, in the same
/// tile chrome as a position, the class colour as the badge.
class HoldingsClassRows extends StatelessWidget {
  /// Creates the rows.
  const HoldingsClassRows({required this.payload, super.key});

  /// `holdings.allocation.v1`, grouped as the toggle asked.
  final ViewPayload payload;

  @override
  Widget build(BuildContext context) {
    final tokens = HomeTokens.of(context);
    final holdings = HoldingsTokens.of(context);
    final ramp = AllocationPalette.of(context)
        .rampFor(payload.text('group_by'));
    final rows = payload.rows('categories');
    return Column(
      children: <Widget>[
        for (var index = 0; index < rows.length; index++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 13, 15, 13),
              decoration: BoxDecoration(
                color: tokens.card,
                border: Border.all(color: holdings.tileBorder),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: ramp[index % ramp.length],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          rows[index].text('label'),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: tokens.text,
                          ),
                        ),
                        Text(
                          rows[index].text('weight.display'),
                          style: TextStyle(fontSize: 11.5, color: tokens.muted),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      Text(
                        rows[index].text('value.display'),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: tokens.text,
                        ),
                      ),
                      _Change(row: rows[index]),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _Change extends StatelessWidget {
  const _Change({required this.row});

  final ViewPayload row;

  @override
  Widget build(BuildContext context) {
    final tokens = HomeTokens.of(context);
    final trend = row.text('trend');
    final tone = switch (trend) {
      'up' => tokens.gain,
      'down' => tokens.loss,
      _ => tokens.muted,
    };
    final glyph = switch (trend) {
      'up' => '▲',
      'down' => '▼',
      _ => '—',
    };
    return Text(
      '$glyph ${row.text('change.display')}',
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: tone),
    );
  }
}
