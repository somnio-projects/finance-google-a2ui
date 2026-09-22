import 'package:finance_app/features/holdings/bloc/holdings_bloc.dart';
import 'package:finance_app/features/holdings/view/holdings_class_rows.dart';
import 'package:finance_app/features/holdings/view/holdings_header_card.dart';
import 'package:finance_app/features/holdings/view/holdings_segment.dart';
import 'package:finance_app/features/holdings/view/position_tile.dart';
import 'package:finance_app/features/shell/view/tab_app_bar.dart';
import 'package:finance_app/theme/home_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// `Holdings.dc.html`: app bar · the allocation card · the segmented
/// control · the position list (spec frontend/0009). Reads bloc state only.
class HoldingsView extends StatelessWidget {
  /// Creates the view.
  const HoldingsView({super.key});

  /// The design's side gutter.
  static const double gutter = 16;

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
        if (positions == null) {
          return const Center(child: CircularProgressIndicator());
        }
        final bloc = context.read<HoldingsBloc>();
        final allocation = state.allocation;
        return ColoredBox(
          color: tokens.page,
          child: ListView(
            padding: EdgeInsets.zero,
            children: <Widget>[
              TabAppBar(title: positions.text('title')),
              if (allocation != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(gutter, 6, gutter, 0),
                  child: HoldingsHeaderCard(
                    positions: positions,
                    allocation: allocation,
                    groupBy: state.groupBy,
                    onGroupBy: (value) =>
                        bloc.add(HoldingsGroupByChanged(value)),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(gutter, 16, gutter, 4),
                child: HoldingsSegment(
                  selected: state.list,
                  onSelected: (list) => bloc.add(HoldingsListChanged(list)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(gutter, 8, gutter, 24),
                child: switch (state.list) {
                  HoldingsList.positions => PositionList(payload: positions),
                  HoldingsList.classes => HoldingsClassRows(
                    payload: allocation ?? positions,
                  ),
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
