import 'package:finance_app/features/holdings/view/position_details.dart';
import 'package:finance_app/features/holdings/view/position_head.dart';
import 'package:finance_app/theme/holdings_tokens.dart';
import 'package:finance_app/theme/home_tokens.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';

/// One row per position; the tapped one expands to its details and the
/// hand-off (the design shows NVDA pressed). The first row starts expanded.
class PositionList extends StatefulWidget {
  /// Creates the list.
  const PositionList({required this.payload, super.key});

  /// `holdings.positions.v1`.
  final ViewPayload payload;

  @override
  State<PositionList> createState() => _PositionListState();
}

class _PositionListState extends State<PositionList> {
  int? _expanded = 0;

  @override
  Widget build(BuildContext context) {
    final rows = widget.payload.rows('positions');
    final askLabel = widget.payload.text('ask_label');
    return Column(
      children: <Widget>[
        for (var index = 0; index < rows.length; index++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: PositionTile(
              row: rows[index],
              askLabel: askLabel,
              expanded: index == _expanded,
              onTap: () =>
                  setState(() => _expanded = _expanded == index ? null : index),
            ),
          ),
      ],
    );
  }
}

/// A position row, collapsed or expanded (spec frontend/0009 §2).
class PositionTile extends StatelessWidget {
  /// Creates the tile.
  const PositionTile({
    required this.row,
    required this.askLabel,
    required this.expanded,
    required this.onTap,
    super.key,
  });

  /// One entry of `positions[]`.
  final ViewPayload row;

  /// `ask_label`, the hand-off's caption.
  final String askLabel;

  /// Whether the details and the hand-off show.
  final bool expanded;

  /// Toggles [expanded].
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = HomeTokens.of(context);
    final holdings = HoldingsTokens.of(context);
    final isCash = row.flag('is_cash');
    final trend = row.text('day_trend');
    final accent = switch (trend) {
      'up' => tokens.gain,
      'down' => tokens.loss,
      _ => holdings.neutralAccent,
    };
    return Semantics(
      button: true,
      label: '${row.text('name')} ${row.text('value.display')}',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: tokens.card,
            border: Border.all(
              color: expanded ? holdings.expandedBorder : holdings.tileBorder,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: expanded
                ? const <BoxShadow>[
                    BoxShadow(
                      color: Color(0x2E4F5DFF),
                      blurRadius: 8,
                      spreadRadius: -2,
                      offset: Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          // The design's "thin left-border accent" is a 4px strip inside the
          // rounded card. It is a child rather than a border side because a
          // `Border` with one side in a different colour cannot be painted
          // with a radius (Flutter asserts on it), and the corners must stay
          // round.
          child: Stack(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Column(
                  children: <Widget>[
                    ColoredBox(
                      color: expanded ? holdings.expandedHead : tokens.card,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(10, 13, 15, 13),
                        child: PositionHead(row: row, isCash: isCash),
                      ),
                    ),
                    if (expanded && !isCash)
                      PositionDetails(row: row, askLabel: askLabel),
                  ],
                ),
              ),
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: 4,
                child: ColoredBox(color: accent),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
