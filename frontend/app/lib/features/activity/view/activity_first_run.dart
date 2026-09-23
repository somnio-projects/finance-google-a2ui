import 'package:finance_app/features/activity/view/activity_chips.dart';
import 'package:finance_app/features/shell/view/pinned_header.dart';
import 'package:finance_app/skeleton/skeleton_rows.dart';
import 'package:finance_app/skeleton/skeleton_shimmer.dart';
import 'package:finance_app/theme/home_tokens.dart';
import 'package:flutter/material.dart';

/// The Activity tab before its first payload: title, filter chips, the note
/// line and the timeline, every block a shimmer at the size the real one
/// takes (spec frontend/0020 AC-4).
///
/// The chips are drawn as pills rather than as words, because their words are
/// `filters[]` — the backend's, and not yet arrived. Inventing `All · Buys ·
/// Sells` here would be the client writing the backend's labels (N-9).
class ActivityFirstRun extends StatelessWidget {
  /// Creates the page.
  const ActivityFirstRun({super.key});

  /// How many chips stand in for the filter row.
  static const int chipCount = 5;

  /// How many entries stand in for the timeline.
  static const int rowCount = 6;

  /// One entry tile's height.
  static const double rowHeight = 60;

  @override
  Widget build(BuildContext context) {
    final tokens = HomeTokens.of(context);
    return ColoredBox(
      color: tokens.page,
      // Pinned, title and chips together, exactly as the loaded tab pins
      // them (spec frontend/0024 OD-5, OD-6).
      child: Column(
        children: <Widget>[
          PinnedHeader(
            color: tokens.header,
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: EdgeInsets.fromLTRB(20, 12, 20, 14),
                  child: SkeletonShimmer(width: 130, height: 24, radius: 6),
                ),
                Padding(
                  padding: EdgeInsets.only(bottom: 14),
                  child: _ChipRow(),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: const <Widget>[
                Padding(
                  padding: EdgeInsets.fromLTRB(20, 12, 20, 6),
                  child: SkeletonShimmer(width: 210, height: 11, radius: 5),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 24),
                  child: SkeletonRows(
                    count: rowCount,
                    height: rowHeight,
                    gap: 8,
                    radius: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The filter row as pills, in the widths the design's chips take.
///
/// Scrolls sideways like [ActivityChips] does: five chips are wider than a
/// 390-point phone, and a placeholder that overflows where the real row
/// scrolls is a placeholder of the wrong shape.
class _ChipRow extends StatelessWidget {
  const _ChipRow();

  /// The chips' widths, in the order the design lists them.
  static const List<double> widths = <double>[54, 62, 62, 82, 86];

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Row(
      children: <Widget>[
        for (var index = 0; index < ActivityFirstRun.chipCount; index++)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: SkeletonShimmer(width: widths[index], height: 32, radius: 9),
          ),
      ],
    ),
  );
}
