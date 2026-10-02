import 'package:finance_app/features/shell/view/filter_chip_tile.dart';
import 'package:finance_app/theme/home_tokens.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';

/// The Holdings filter, as a sheet rather than a fourth row of controls.
///
/// The tab already stacks an app bar, the header card's `By asset class /
/// By sector` toggle and the `By position / By asset class` segment; one
/// more always-visible row would be the densest screen in the app
/// (spec frontend/0018 OD-3).
///
/// Its chips are `holdings.positions.v1`'s own `filters[]`, so the words
/// *All*, *Equities*, *Bonds* are the server's and appear nowhere in this
/// file (N-9).
class HoldingsFilterSheet extends StatelessWidget {
  /// Creates the sheet's body.
  const HoldingsFilterSheet({
    required this.payload,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  /// The sheet's own title — it names a control, not a figure.
  static const String title = 'Filter holdings';

  /// `holdings.positions.v1` — its `filters[]`.
  final ViewPayload payload;

  /// The `asset_class` in force.
  final String selected;

  /// Called with the tapped chip's `key`; the caller closes the sheet.
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final tokens = HomeTokens.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: tokens.text,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final chip in payload.rows('filters'))
                  FilterChipTile(
                    label: chip.text('label'),
                    selected: chip.text('key') == selected,
                    onTap: () => onSelected(chip.text('key')),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
