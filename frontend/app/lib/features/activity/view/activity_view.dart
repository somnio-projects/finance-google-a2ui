import 'package:finance_app/features/activity/bloc/activity_bloc.dart';
import 'package:finance_app/features/activity/view/activity_chips.dart';
import 'package:finance_app/features/activity/view/activity_entry_tile.dart';
import 'package:finance_app/features/shell/view/tab_app_bar.dart';
import 'package:finance_app/features/shell/view/tab_search_field.dart';
import 'package:finance_app/theme/activity_tokens.dart';
import 'package:finance_app/theme/home_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// `Activity.dc.html`: app bar · filter chips · the simulation note · the
/// dated sections (spec frontend/0009). Reads bloc state only.
class ActivityView extends StatelessWidget {
  /// Creates the view.
  const ActivityView({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = HomeTokens.of(context);
    final activity = ActivityTokens.of(context);
    return BlocBuilder<ActivityBloc, ActivityState>(
      builder: (context, state) {
        final timeline = state.timeline;
        if (state.status == ActivityStatus.failure) {
          return TabFailure(
            message: state.failure?.message ?? 'The request failed.',
          );
        }
        if (timeline == null) {
          return const Center(child: CircularProgressIndicator());
        }
        final bloc = context.read<ActivityBloc>();
        return ColoredBox(
          color: tokens.page,
          child: ListView(
            padding: EdgeInsets.zero,
            children: <Widget>[
              TabAppBar(
                title: timeline.text('title'),
                // Search only: the `kind` chips below already are this
                // tab's filter (spec frontend/0018 OD-2).
                search: TabSearch(
                  query: state.query,
                  onChanged: (query) => bloc.add(ActivityQueryChanged(query)),
                ),
              ),
              ColoredBox(
                color: tokens.header,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 2, 0, 12),
                  child: ActivityChips(
                    payload: timeline,
                    selected: state.kind,
                    onSelected: (kind) => bloc.add(ActivityKindChanged(kind)),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: activity.noteDot,
                        shape: BoxShape.circle,
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: activity.noteDot.withValues(alpha: 0.18),
                            spreadRadius: 3,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        timeline.text('note'),
                        style: TextStyle(fontSize: 11, color: activity.note),
                      ),
                    ),
                  ],
                ),
              ),
              if (timeline.rows('groups').isEmpty)
                TabEmpty(message: timeline.text('empty')),
              for (final group in timeline.rows('groups')) ...<Widget>[
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
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}
