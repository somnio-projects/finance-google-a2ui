import 'package:finance_app/theme/holdings_tokens.dart';
import 'package:flutter/material.dart';

/// One pill of the `By asset class | By sector` toggle.
class GroupByPill {
  /// Creates the pill.
  const GroupByPill({required this.groupBy, required this.label});

  /// The declared `group_by` value it sets.
  final String groupBy;

  /// Its words.
  final String label;
}

/// The two groupings the card offers, in the design's order.
const List<GroupByPill> groupByPills = <GroupByPill>[
  GroupByPill(groupBy: 'asset_class', label: 'By asset class'),
  GroupByPill(groupBy: 'sector', label: 'By sector'),
];

/// The soft toggle inside the card: a tinted track, a white pill.
class HoldingsToggle extends StatelessWidget {
  /// Creates the toggle.
  const HoldingsToggle({
    required this.selected,
    required this.onSelected,
    super.key,
  });

  /// The `group_by` in force.
  final String selected;

  /// Called with the tapped pill's `group_by`.
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final tokens = HoldingsTokens.of(context);
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: tokens.toggle,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          for (final pill in groupByPills)
            Expanded(
              child: Semantics(
                button: true,
                selected: pill.groupBy == selected,
                label: pill.label,
                excludeSemantics: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onSelected(pill.groupBy),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    alignment: Alignment.center,
                    decoration: pill.groupBy == selected
                        ? BoxDecoration(
                            color: tokens.toggleSelected,
                            borderRadius: BorderRadius.circular(9),
                            boxShadow: const <BoxShadow>[
                              BoxShadow(
                                color: Color(0x14000000),
                                blurRadius: 2,
                                offset: Offset(0, 1),
                              ),
                            ],
                          )
                        : null,
                    child: Text(
                      pill.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: pill.groupBy == selected
                            ? FontWeight.w500
                            : FontWeight.w400,
                        color: pill.groupBy == selected
                            ? tokens.toggleSelectedText
                            : tokens.toggleText,
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
