import 'package:finance_app/components/component_registry.dart';
import 'package:finance_app/components/component_skeleton_host.dart';
import 'package:finance_app/features/holdings/bloc/holdings_bloc.dart';
import 'package:finance_app/features/holdings/view/holdings_view.dart';
import 'package:finance_app/features/shell/view/pinned_header.dart';
import 'package:finance_app/skeleton/skeleton_rows.dart';
import 'package:finance_app/skeleton/skeleton_shimmer.dart';
import 'package:finance_app/theme/home_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The Holdings tab before its first payload: the tab laid out as it will be,
/// every block a shimmer — title, header card, segment, position rows — so
/// entering the tab looks like the tab arriving rather than a spinner in a
/// void (spec frontend/0020 AC-1, the counterpart of `HomeFirstRun`).
///
/// The ring inside the card is **the component's own skeleton**, reached
/// through the same registry a loaded card resolves through, so this page
/// does not draw a second placeholder for a component that already has one
/// (spec frontend/0015 OD-3).
///
/// It prints no word and no figure: none has arrived (N-3, N-9).
class HoldingsFirstRun extends StatelessWidget {
  /// Creates the page.
  const HoldingsFirstRun({super.key});

  /// How many position rows stand in for the list — the artboard's count.
  static const int rowCount = 5;

  /// One row's height, the collapsed `PositionTile`'s.
  static const double rowHeight = 66;

  @override
  Widget build(BuildContext context) {
    final tokens = HomeTokens.of(context);
    return ColoredBox(
      color: tokens.page,
      // Pinned, exactly as the loaded tab pins it (spec frontend/0024 OD-6).
      child: Column(
        children: <Widget>[
          PinnedHeader(
            color: tokens.header,
            child: const Padding(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 14),
              child: SkeletonShimmer(width: 150, height: 24, radius: 6),
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: const <Widget>[
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    HoldingsView.gutter,
                    6,
                    HoldingsView.gutter,
                    0,
                  ),
                  child: _CardSkeleton(),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    HoldingsView.gutter,
                    16,
                    HoldingsView.gutter,
                    4,
                  ),
                  child: SkeletonShimmer(height: 38, radius: 20),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    HoldingsView.gutter,
                    8,
                    HoldingsView.gutter,
                    24,
                  ),
                  child: SkeletonRows(count: rowCount, height: rowHeight),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The header card's chrome with shimmer where its figures go.
class _CardSkeleton extends StatelessWidget {
  const _CardSkeleton();

  @override
  Widget build(BuildContext context) {
    final tokens = HomeTokens.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.card,
        border: Border.all(color: tokens.cardBorder),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      SkeletonShimmer(width: 72, height: 12, radius: 5),
                      SizedBox(height: 6),
                      SkeletonShimmer(width: 170, height: 28),
                      SizedBox(height: 7),
                      SkeletonShimmer(width: 140, height: 13, radius: 5),
                    ],
                  ),
                ),
                SizedBox(width: 12),
                SkeletonShimmer(width: 84, height: 28, radius: 14),
              ],
            ),
            const SizedBox(height: 16),
            const SkeletonShimmer(height: 34, radius: 12),
            const SizedBox(height: 16),
            ComponentSkeletonHost(
              registry: context.read<ComponentRegistry>(),
              view: HoldingsBloc.allocationView,
            ),
          ],
        ),
      ),
    );
  }
}
