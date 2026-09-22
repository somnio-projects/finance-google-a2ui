import 'package:finance_app/features/activity/bloc/activity_bloc.dart';
import 'package:finance_app/features/activity/view/activity_chips.dart';
import 'package:finance_app/features/activity/view/activity_first_run.dart';
import 'package:finance_app/features/activity/view/activity_sections.dart';
import 'package:finance_app/features/shell/view/tab_app_bar.dart';
import 'package:finance_app/skeleton/skeleton_rows.dart';
import 'package:finance_app/skeleton/skeleton_switcher.dart';
import 'package:finance_app/theme/activity_tokens.dart';
import 'package:finance_app/theme/home_tokens.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// `Activity.dc.html`: app bar · filter chips · the simulation note · the
/// dated sections (spec frontend/0009). Reads bloc state only.
///
/// A filter change keeps the bar, the chips and the note — `kind` governs
/// none of them — and gives the sections to a skeleton until the answer
/// lands, so the previous filter's rows are never shown under the new chip
/// (spec frontend/0020 OD-3, AC-5).
class ActivityView extends StatelessWidget {
  /// Creates the view.
  const ActivityView({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = HomeTokens.of(context);
    return BlocBuilder<ActivityBloc, ActivityState>(
      builder: (context, state) {
        final timeline = state.timeline;
        if (state.status == ActivityStatus.failure) {
          return TabFailure(
            message: state.failure?.message ?? 'The request failed.',
          );
        }
        if (timeline == null) return const ActivityFirstRun();
        final bloc = context.read<ActivityBloc>();
        return ColoredBox(
          color: tokens.page,
          child: ListView(
            padding: EdgeInsets.zero,
            children: <Widget>[
              TabAppBar(title: timeline.text('title')),
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
              _Note(payload: timeline),
              SkeletonSwitcher(
                loading: state.status == ActivityStatus.loading,
                skeleton: const Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: SkeletonRows(
                    count: ActivityFirstRun.rowCount,
                    height: ActivityFirstRun.rowHeight,
                    gap: 8,
                    radius: 12,
                  ),
                ),
                child: ActivitySections(payload: timeline),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}

/// The simulation disclosure, rendered verbatim (N-9). `kind` does not govern
/// it, so a filter change leaves it on screen.
class _Note extends StatelessWidget {
  const _Note({required this.payload});

  final ViewPayload payload;

  @override
  Widget build(BuildContext context) {
    final activity = ActivityTokens.of(context);
    return Padding(
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
              payload.text('note'),
              style: TextStyle(fontSize: 11, color: activity.note),
            ),
          ),
        ],
      ),
    );
  }
}
