import 'package:finance_app/theme/home_tokens.dart';
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
  Widget build(BuildContext context) {
    final tokens = HomeTokens.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: <Widget>[
          for (final chip in payload.rows('filters'))
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _Chip(
                label: chip.text('label'),
                selected: chip.text('key') == selected,
                onTap: () => onSelected(chip.text('key')),
                tokens: tokens,
              ),
            ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.tokens,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final HomeTokens tokens;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: label,
    excludeSemantics: true,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? tokens.segmentSelected : tokens.card,
          border: selected ? null : Border.all(color: tokens.segmentBorder),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(
          selected ? '✓ $label' : label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
            color: selected ? tokens.segmentSelectedText : tokens.segmentText,
          ),
        ),
      ),
    ),
  );
}
