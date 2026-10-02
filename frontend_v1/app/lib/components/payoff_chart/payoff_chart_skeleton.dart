import 'package:finance_app/charts/chart_palette.dart';
import 'package:finance_app/components/payoff_chart/payoff_chart_card.dart';
import 'package:finance_app/components/payoff_chart/payoff_chart_skeleton_painter.dart';
import 'package:finance_app/skeleton/skeleton_pulse.dart';
import 'package:finance_app/theme/skeleton_tokens.dart';
import 'package:flutter/material.dart';

/// The `RiskPayoffChart` card while `payoff()` runs: the catalog page's
/// `Loading` state — four faint gridlines, three tick stubs, a dashed rising
/// line, all breathing, with the tool's name in a pill where the curve will
/// be, and two flat bars under a rule where the legend lands.
class PayoffChartSkeleton extends StatelessWidget {
  /// Creates the skeleton.
  const PayoffChartSkeleton({super.key});

  /// The words in the pill.
  static const String caption = 'payoff()…';

  /// The artboard's plot box, `viewBox="0 0 500 280"`; the painter scales it.
  static const double designWidth = 500;

  /// See [designWidth].
  static const double designHeight = 280;

  @override
  Widget build(BuildContext context) {
    final palette = ChartPalette.of(context);
    final tokens = SkeletonTokens.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border.all(color: palette.border),
        borderRadius: BorderRadius.circular(PayoffChartCard.radius),
      ),
      child: Padding(
        padding: PayoffChartCard.padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            AspectRatio(
              aspectRatio: designWidth / designHeight,
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  SkeletonPulse(
                    child: CustomPaint(
                      painter: PayoffSkeletonPainter(color: tokens.bar),
                    ),
                  ),
                  Center(
                    child: Container(
                      height: 24,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: tokens.pill,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        caption,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          fontFamily: 'Roboto Mono',
                          color: tokens.caption,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.only(top: 10),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: tokens.pill)),
              ),
              child: SkeletonPulse(
                child: Row(
                  children: <Widget>[
                    _FlatBar(width: 80, color: tokens.bar),
                    const SizedBox(width: 10),
                    _FlatBar(width: 120, color: tokens.bar),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FlatBar extends StatelessWidget {
  const _FlatBar({required this.width, required this.color});

  final double width;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: 11,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(6),
    ),
  );
}
