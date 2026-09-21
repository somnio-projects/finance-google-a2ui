import 'package:finance_app/theme/home_tokens.dart';
import 'package:flutter/material.dart';

/// The Activity tab's frame: its title and filter chips, as
/// `Activity.dc.html` draws them, above the space its timeline will fill.
///
/// The timeline itself is a projection over the ledger (`activity.timeline`)
/// that does not exist yet; this page says so in the design's own words for
/// the empty state rather than drawing rows it has no data for.
class ActivityPage extends StatelessWidget {
  /// Creates the page.
  const ActivityPage({super.key});

  /// The design's filter chips, in its order.
  static const List<String> filters = <String>[
    'All',
    'Buys',
    'Sells',
    'Dividends',
    'Deposits',
  ];

  @override
  Widget build(BuildContext context) {
    final tokens = HomeTokens.of(context);
    return ColoredBox(
      color: tokens.page,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        children: <Widget>[
          Text(
            'Activity',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w500,
              color: tokens.text,
            ),
          ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: <Widget>[
                for (var index = 0; index < filters.length; index++)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _Filter(label: filters[index], selected: index == 0),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Simulated activity — resets each session.',
            style: TextStyle(fontSize: 12, color: tokens.muted),
          ),
        ],
      ),
    );
  }
}

class _Filter extends StatelessWidget {
  const _Filter({required this.label, required this.selected});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final tokens = HomeTokens.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? tokens.segmentSelected : tokens.chip,
        border: Border.all(
          color: selected ? tokens.segmentSelected : tokens.chipBorder,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        selected ? '✓ $label' : label,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w500,
          color: selected ? tokens.segmentSelectedText : tokens.segmentText,
        ),
      ),
    );
  }
}
