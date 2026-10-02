import 'package:finance_app/features/activity/view/activity_entry_tile.dart';
import 'package:finance_app/features/shell/view/tab_app_bar.dart';
import 'package:finance_app/theme/activity_tokens.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';

/// The timeline itself: one dated section per `groups[]`, one tile per
/// `entries[]`, in arrival order (N-10).
///
/// Extracted from the view because this is exactly what the `kind` option
/// governs, and therefore exactly what a filter change replaces with a
/// skeleton while the answer is on the way (spec frontend/0020 OD-3).
///
/// The same reasoning puts the **empty** case here rather than in the view:
/// `kind` and `query` govern whether there are any rows at all, so the
/// sentence that stands in for them is swapped with them. It is the
/// payload's own `empty`, never one composed on the device (0018 OD-6).
class ActivitySections extends StatelessWidget {
  /// Creates the sections for [payload].
  const ActivitySections({required this.payload, super.key});

  /// `activity.timeline.v1` — its `groups[]`.
  final ViewPayload payload;

  @override
  Widget build(BuildContext context) {
    final activity = ActivityTokens.of(context);
    if (payload.rows('groups').isEmpty) {
      return TabEmpty(message: payload.text('empty'));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (final group in payload.rows('groups')) ...<Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
            child: Text(
              group.text('label'),
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.4,
                color: activity.section,
              ),
            ),
          ),
          for (final entry in group.rows('entries'))
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: ActivityEntryTile(entry: entry),
            ),
        ],
      ],
    );
  }
}
