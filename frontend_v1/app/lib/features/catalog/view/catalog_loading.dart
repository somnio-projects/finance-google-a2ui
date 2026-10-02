import 'package:finance_app/features/catalog/view/catalog_board.dart';
import 'package:finance_app/features/catalog/view/catalog_grid.dart';
import 'package:finance_app/features/catalog/view/catalog_top_bar.dart';
import 'package:finance_app/skeleton/skeleton_shimmer.dart';
import 'package:flutter/material.dart';

/// The gallery index while `GET /v1/views` is on the way: the board and its
/// top bar, then the header, the legend and the card grid as shimmer at the
/// sizes they will take (spec frontend/0020 AC-6).
///
/// The top bar is real because none of it comes from the backend — it is the
/// page's own chrome, and hiding it would make the board flash.
class CatalogIndexLoading extends StatelessWidget {
  /// Creates the page.
  const CatalogIndexLoading({super.key});

  /// How many cards stand in for the grid.
  ///
  /// A placeholder count, not a fact about the backend: the real grid draws
  /// one card per entry `GET /v1/views` returns that this build renders, and
  /// nothing here is told when that number changes. Six is what it happens
  /// to be, and the only thing this constant has to get right is *roughly
  /// how much of the board is about to fill*.
  static const int cardCount = 6;

  /// One card's height.
  static const double cardHeight = 280;

  @override
  Widget build(BuildContext context) => CatalogBoard(
    header: const CatalogTopBar(),
    children: <Widget>[
      Padding(
        padding: const EdgeInsets.fromLTRB(32, 32, 32, 36),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const SkeletonShimmer(width: 330, height: 30, radius: 8),
            const SizedBox(height: 12),
            const SkeletonShimmer(width: 520, height: 14, radius: 6),
            const SizedBox(height: 26),
            const SkeletonShimmer(height: 52, radius: 12),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) => _CardGrid(
                columns: CatalogGrid.columnsFor(constraints.maxWidth),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

/// The grid's cards, laid out in the same column count the real grid uses so
/// nothing reflows when the entries land.
class _CardGrid extends StatelessWidget {
  const _CardGrid({required this.columns});

  final int columns;

  @override
  Widget build(BuildContext context) {
    final rows = (CatalogIndexLoading.cardCount + columns - 1) ~/ columns;
    return Column(
      children: <Widget>[
        for (var row = 0; row < rows; row++)
          Padding(
            padding: EdgeInsets.only(
              bottom: row == rows - 1 ? 0 : CatalogGrid.gap,
            ),
            child: Row(
              children: <Widget>[
                for (var column = 0; column < columns; column++) ...<Widget>[
                  if (column > 0) const SizedBox(width: CatalogGrid.gap),
                  const Expanded(
                    child: SkeletonShimmer(
                      height: CatalogIndexLoading.cardHeight,
                      radius: 20,
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

/// A component's detail page while its catalog entry and Zone 1 renders are
/// on the way: the board, the top bar, the header and the three zones as
/// shimmer (spec frontend/0020 AC-6).
class CatalogDetailLoading extends StatelessWidget {
  /// Creates the page.
  const CatalogDetailLoading({super.key});

  /// Zone 1's height — the preview column's.
  static const double previewHeight = 420;

  /// Zones 2 and 3's heights, top to bottom.
  static const List<double> sideHeights = <double>[240, 164];

  @override
  Widget build(BuildContext context) => CatalogBoard(
    header: const CatalogTopBar(),
    children: <Widget>[
      Padding(
        padding: const EdgeInsets.fromLTRB(32, 30, 32, 34),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const SkeletonShimmer(width: 300, height: 28, radius: 8),
            const SizedBox(height: 10),
            const SkeletonShimmer(width: 460, height: 13, radius: 6),
            const SizedBox(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Expanded(
                  flex: 155,
                  child: SkeletonShimmer(height: previewHeight, radius: 16),
                ),
                const SizedBox(width: 20),
                Expanded(
                  flex: 100,
                  child: Column(
                    children: <Widget>[
                      for (final height in sideHeights)
                        Padding(
                          padding: EdgeInsets.only(
                            bottom: height == sideHeights.last ? 0 : 16,
                          ),
                          child: SkeletonShimmer(height: height, radius: 16),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ],
  );
}
