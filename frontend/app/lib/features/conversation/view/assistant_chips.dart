import 'package:finance_app/theme/assistant_tokens.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';

/// The follow-ups the last turn recommended, one horizontal row above the
/// composer (spec frontend/0011 OD-3). The words are the backend's; a tap
/// sends the chip's **key**, never its label.
class SuggestionChips extends StatelessWidget {
  /// Creates the row.
  const SuggestionChips({
    required this.suggestions,
    required this.onTap,
    super.key,
  });

  /// The chips, in the backend's order (N-10).
  final List<Suggestion> suggestions;

  /// Called with the tapped chip.
  final ValueChanged<Suggestion> onTap;

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty) return const SizedBox.shrink();
    final assistant = AssistantTokens.of(context);
    return SizedBox(
      height: 41,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(15, 4, 15, 4),
        itemCount: suggestions.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final chip = suggestions[index];
          return Semantics(
            button: true,
            label: chip.label,
            excludeSemantics: true,
            child: GestureDetector(
              onTap: () => onTap(chip),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: assistant.chip,
                  border: Border.all(color: assistant.chipBorder),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  chip.label,
                  style: TextStyle(fontSize: 12.5, color: assistant.chipText),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
