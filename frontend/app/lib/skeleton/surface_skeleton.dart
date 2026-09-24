import 'package:finance_app/theme/assistant_tokens.dart';
import 'package:finance_app/theme/home_tokens.dart';
import 'package:flutter/material.dart';

/// The design's *A2UI progressive composition* state: the card a surface
/// will occupy, drawn as bars and pills while its payload is on the way
/// (spec frontend/0011 OD-2).
class SurfaceSkeleton extends StatelessWidget {
  /// Creates the skeleton.
  const SurfaceSkeleton({super.key});

  /// The seven bar heights the artboard draws, left to right.
  static const List<double> barHeights = <double>[105, 60, 42, 33, 51, 39, 117];

  @override
  Widget build(BuildContext context) {
    final tokens = HomeTokens.of(context);
    final assistant = AssistantTokens.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
      decoration: BoxDecoration(
        color: tokens.card,
        border: Border.all(color: tokens.cardBorder),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              _Bar(
                width: 120,
                height: 13,
                radius: 5,
                color: assistant.skeletonBar,
              ),
              const Spacer(),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: assistant.dot,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'Composing UI…',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                  color: assistant.composing,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 120,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                for (final height in barHeights)
                  _Bar(
                    width: 37,
                    height: height,
                    radius: 4,
                    color: assistant.skeletonBar,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              for (var index = 0; index < 3; index++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: _Bar(
                    width: 60,
                    height: 10,
                    radius: 5,
                    color: assistant.skeletonBar,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.width,
    required this.height,
    required this.radius,
    required this.color,
  });

  final double width;
  final double height;
  final double radius;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
    ),
  );
}
