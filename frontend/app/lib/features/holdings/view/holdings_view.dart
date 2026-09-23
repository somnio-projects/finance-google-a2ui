import 'dart:async';

import 'package:finance_app/features/holdings/bloc/holdings_bloc.dart';
import 'package:finance_app/features/holdings/view/holdings_class_rows.dart';
import 'package:finance_app/features/holdings/view/holdings_filter_sheet.dart';
import 'package:finance_app/features/holdings/view/holdings_first_run.dart';
import 'package:finance_app/features/holdings/view/holdings_header_card.dart';
import 'package:finance_app/features/holdings/view/holdings_segment.dart';
import 'package:finance_app/features/holdings/view/position_tile.dart';
import 'package:finance_app/features/shell/view/tab_app_bar.dart';
import 'package:finance_app/features/shell/view/tab_search_field.dart';
import 'package:finance_app/skeleton/skeleton_rows.dart';
import 'package:finance_app/skeleton/skeleton_switcher.dart';
import 'package:finance_app/theme/home_tokens.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// `Holdings.dc.html`: app bar · the allocation card · the segmented
/// control · the position list (spec frontend/0009). Reads bloc state only.
class HoldingsView extends StatelessWidget {
  /// Creates the view.
  const HoldingsView({super.key});

  /// The design's side gutter.
  static const double gutter = 16;

  /// Open the class filter; picking a chip refetches the list and closes it.
  static Future<void> _openFilter(
    BuildContext context,
    HoldingsBloc bloc,
    HoldingsState state,
    ViewPayload positions,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => HoldingsFilterSheet(
        payload: positions,
        selected: state.assetClass,
        onSelected: (value) {
          bloc.add(HoldingsAssetClassChanged(value));
          Navigator.of(sheetContext).pop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = HomeTokens.of(context);
    return BlocBuilder<HoldingsBloc, HoldingsState>(
      builder: (context, state) {
        final positions = state.positions;
        if (state.status == HoldingsStatus.failure) {
          return TabFailure(
            message: state.failure?.message ?? 'The request failed.',
          );
        }
        // Before the first payload the tab is drawn in its own shape, as
        // shimmer, rather than as a spinner in a void (spec 0020 AC-1).
        if (positions == null) return const HoldingsFirstRun();
        final bloc = context.read<HoldingsBloc>();
        final allocation = state.allocation;
        return ColoredBox(
          color: tokens.page,
          // The bar is the Column's child and the list is the Expanded one:
          // the search and filter controls a reader reaches for while
          // scrolling a long list used to be the first things the list hid
          // (spec frontend/0024).
          child: Column(
            children: <Widget>[
              TabAppBar(
                title: positions.text('title'),
                search: TabSearch(
                  query: state.query,
                  onChanged: (query) => bloc.add(HoldingsQueryChanged(query)),
                ),
                onFilter: () =>
                    unawaited(_openFilter(context, bloc, state, positions)),
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: <Widget>[
                    if (allocation != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          gutter,
                          6,
                          gutter,
                          0,
                        ),
                        child: HoldingsHeaderCard(
                          positions: positions,
                          allocation: allocation,
                          groupBy: state.groupBy,
                          loading: state.allocationLoading,
                          onGroupBy: (value) =>
                              bloc.add(HoldingsGroupByChanged(value)),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(gutter, 16, gutter, 4),
                      child: HoldingsSegment(
                        selected: state.list,
                        onSelected: (list) =>
                            bloc.add(HoldingsListChanged(list)),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(gutter, 8, gutter, 24),
                      child: switch (state.list) {
                        // `asset_class` and `query` DO govern this list, so an
                        // empty one is the payload's own sentence (0018 OD-6);
                        // `group_by` does not, so a regrouping leaves it alone
                        // (spec 0020 OD-3).
                        HoldingsList.positions
                            when positions.rows('positions').isEmpty =>
                          TabEmpty(message: positions.text('empty')),
                        HoldingsList.positions => PositionList(
                          payload: positions,
                        ),
                        HoldingsList.classes => SkeletonSwitcher(
                          loading: state.allocationLoading,
                          skeleton: const SkeletonRows(
                            count: HoldingsFirstRun.rowCount,
                            height: HoldingsFirstRun.rowHeight,
                          ),
                          child: HoldingsClassRows(
                            payload: allocation ?? positions,
                          ),
                        ),
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
