import 'package:finance_app/components/portfolio_summary/home_hero_loading.dart';
import 'package:finance_app/features/home/view/home_view.dart';
import 'package:finance_app/features/shell/view/pinned_header.dart';
import 'package:finance_app/skeleton/skeleton_shimmer.dart';
import 'package:finance_app/theme/home_tokens.dart';
import 'package:flutter/material.dart';

/// The Home tab before its first payload: the page laid out as it will be,
/// every block a shimmer — header, hero, allocation card, questions, movers —
/// so the first paint is the page arriving rather than a spinner in a void
/// (spec frontend/0015 OD-2).
///
/// Nothing here is a word the backend owns: no greeting, no label, no
/// figure. The one caption is the hero's `Loading…`.
class HomeFirstRun extends StatelessWidget {
  /// Creates the page.
  const HomeFirstRun({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = HomeTokens.of(context);
    return ColoredBox(
      color: tokens.page,
      // Pinned, exactly as the loaded page pins it: a skeleton whose layout
      // differs from the page it stands in for is the wrong shape
      // (spec frontend/0024 OD-6).
      child: Column(
        children: <Widget>[
          PinnedHeader(
            color: tokens.header,
            child: const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 14),
              child: Row(
                children: <Widget>[
                  SkeletonShimmer(
                    width: 40,
                    height: 40,
                    shape: BoxShape.circle,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        SkeletonShimmer(width: 80, height: 12, radius: 5),
                        SizedBox(height: 6),
                        SkeletonShimmer(width: 120, height: 17, radius: 6),
                      ],
                    ),
                  ),
                  SizedBox(width: 12),
                  SkeletonShimmer(width: 128, height: 28, radius: 20),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: const <Widget>[
                Padding(
                  padding: EdgeInsets.fromLTRB(20, 18, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      SkeletonShimmer(width: 110, height: 12.5, radius: 5),
                      SizedBox(height: 8),
                      SkeletonShimmer(width: 230, height: 40, radius: 8),
                      SizedBox(height: 12),
                      HomeHeroLoading(),
                      SizedBox(height: 16),
                      SkeletonShimmer(height: 38, radius: 20),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    HomeView.gutter,
                    18,
                    HomeView.gutter,
                    0,
                  ),
                  child: SkeletonShimmer(height: 236, radius: 16),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    HomeView.gutter,
                    22,
                    HomeView.gutter,
                    0,
                  ),
                  child: SkeletonShimmer(height: 44, radius: 22),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    HomeView.gutter,
                    22,
                    HomeView.gutter,
                    24,
                  ),
                  child: SkeletonShimmer(height: 168, radius: 16),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
