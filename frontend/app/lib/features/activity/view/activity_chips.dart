import 'package:finance_app/features/shell/view/filter_chip_tile.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';

/// The filter row: the backend's chips, the selected one filled with a `✓`.
class ActivityChips extends StatelessWidget {
  /// Creates the row.
  const ActivityChips({
    required this.payload,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  /// `activity.timeline.v1` — its `filters[]`.
  final ViewPayload payload;

  /// The `kind` in force.
  final String selected;

  /// Called with the tapped chip's `key`.
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Row(
      children: <Widget>[
        for (final chip in payload.rows('filters'))
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChipTile(
              label: chip.text('label'),
              selected: chip.text('key') == selected,
              onTap: () => onSelected(chip.text('key')),
            ),
          ),
      ],
    ),
  );
}
