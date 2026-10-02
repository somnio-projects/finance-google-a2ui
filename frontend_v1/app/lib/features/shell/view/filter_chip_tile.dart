import 'package:finance_app/theme/home_tokens.dart';
import 'package:flutter/material.dart';

/// One filter chip, selected or not — the leaf both tabs draw.
///
/// Extracted from `ActivityChips` when Holdings grew a filter of its own
/// (spec frontend/0018 OD-3): the Activity tab lays its chips out in a
/// scrolling row and the Holdings sheet wraps them, so what the two share is
/// the chip, not the row.
///
/// The label is always the **payload's** word (N-9); this widget spells
/// nothing but the `✓`.
class FilterChipTile extends StatelessWidget {
  /// Creates the chip.
  const FilterChipTile({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  /// The chip's words, from the payload.
  final String label;

  /// Whether this is the option in force.
  final bool selected;

  /// Called when it is tapped.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = HomeTokens.of(context);
    return Semantics(
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
}
