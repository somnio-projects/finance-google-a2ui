import 'package:finance_app/features/holdings/bloc/holdings_bloc.dart';
import 'package:finance_app/theme/home_tokens.dart';
import 'package:flutter/material.dart';

/// The design's segmented button: `✓ By position` | `By asset class`, the
/// same 38px bordered pill the Home range selector uses.
class HoldingsSegment extends StatelessWidget {
  /// Creates the control.
  const HoldingsSegment({
    required this.selected,
    required this.onSelected,
    super.key,
  });

  /// The list in force.
  final HoldingsList selected;

  /// Called with the tapped segment's list.
  final ValueChanged<HoldingsList> onSelected;

  /// The words per segment, in the design's order.
  static const Map<HoldingsList, String> labels = <HoldingsList, String>{
    HoldingsList.positions: 'By position',
    HoldingsList.classes: 'By asset class',
  };

  @override
  Widget build(BuildContext context) {
    final tokens = HomeTokens.of(context);
    return Container(
      height: 38,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        border: Border.all(color: tokens.segmentBorder),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: <Widget>[
          for (final entry in labels.entries)
            Expanded(
              child: Semantics(
                button: true,
                selected: entry.key == selected,
                label: entry.value,
                excludeSemantics: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onSelected(entry.key),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: entry.key == selected
                          ? tokens.segmentSelected
                          : null,
                      border: entry.key == HoldingsList.classes
                          ? Border(
                              left: BorderSide(color: tokens.segmentBorder),
                            )
                          : null,
                    ),
                    child: Text(
                      entry.key == selected ? '✓ ${entry.value}' : entry.value,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: entry.key == selected
                            ? FontWeight.w500
                            : FontWeight.w400,
                        color: entry.key == selected
                            ? tokens.segmentSelectedText
                            : tokens.segmentText,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
