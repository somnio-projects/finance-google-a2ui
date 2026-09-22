import 'package:finance_app/charts/sparkline_chart.dart';
import 'package:finance_app/features/home/view/home_hero_loading.dart';
import 'package:finance_app/features/home/view/home_range_selector.dart';
import 'package:finance_app/theme/home_tokens.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';

/// Total, change, sparkline and range selector (spec 0026 §2).
///
/// Binds `total.label`, `total.amount.display`, `change.*` and
/// `spark[].value.amount`. The arrow is chosen from `change.trend`, which is
/// the backend's word for the direction — the same arrangement the waterfall
/// uses for `direction`, so no sign is ever read off a string here.
class HomeHero extends StatelessWidget {
  /// Creates the hero.
  const HomeHero({
    required this.payload,
    required this.range,
    required this.onRangeSelected,
    this.loading = false,
    super.key,
  });

  /// `portfolio.summary.v1`.
  final ViewPayload payload;

  /// The selected range code.
  final String range;

  /// Called with the declared code of the range tapped.
  final ValueChanged<String> onRangeSelected;

  /// Whether a range's figures are still on the way. The total stays; the
  /// change and the sparkline give way to [HomeHeroLoading] (spec 0015 OD-1).
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final tokens = HomeTokens.of(context);
    final trend = payload.text('change.trend');
    final tone = switch (trend) {
      'up' => tokens.gain,
      'down' => tokens.loss,
      _ => tokens.muted,
    };
    final glyph = switch (trend) {
      'up' => '▲',
      'down' => '▼',
      _ => '—',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          payload.text('total.label'),
          style: TextStyle(fontSize: 12.5, color: tokens.muted),
        ),
        const SizedBox(height: 2),
        Text(
          payload.text('total.amount.display'),
          style: TextStyle(fontSize: 40, height: 1.05, color: tokens.text),
        ),
        const SizedBox(height: 6),
        if (loading)
          const HomeHeroLoading()
        else ...<Widget>[
          // One text, two spans: the period wraps under the change on a
          // narrow phone instead of overflowing a row of two.
          Text.rich(
            TextSpan(
              children: <InlineSpan>[
                TextSpan(
                  text:
                      '$glyph ${payload.text('change.amount.display')} '
                      '(${payload.text('change.percent.display')})',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w500,
                    color: tone,
                  ),
                ),
                TextSpan(
                  text: '  ${payload.text('change.period')}',
                  style: TextStyle(fontSize: 12.5, color: tokens.muted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SparklineChart(
            values: <double>[
              for (final point in payload.rows('spark'))
                point.geometry('value.amount'),
            ],
            color: tokens.gain,
          ),
        ],
        const SizedBox(height: 16),
        HomeRangeSelector(selected: range, onSelected: onRangeSelected),
      ],
    );
  }
}
