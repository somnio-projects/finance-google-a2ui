import 'package:finance_app/features/home/view/home_questions.dart';
import 'package:finance_app/features/home/view/home_rail_arrow.dart';
import 'package:flutter/material.dart';

/// The horizontal rail of question chips, with what the design's flat row
/// lacked: a fading edge on whichever side has chips off-screen, and a round
/// arrow there that scrolls them into view — so it reads as a slider, not a
/// cut. Both ends: once the reader has gone right, the left edge fades and
/// its arrow brings the first chips back (spec frontend/0012).
class HomeQuestionsRail extends StatefulWidget {
  /// Creates the rail.
  const HomeQuestionsRail({required this.questions, super.key});

  /// Where the forward arrow lives, for tests.
  static const Key arrowKey = Key('questions-rail-arrow');

  /// Where the back arrow lives, for tests.
  static const Key backKey = Key('questions-rail-back');

  /// How far one tap on the arrow scrolls.
  static const double step = 220;

  /// The questions, in the backend's order.
  final List<String> questions;

  @override
  State<HomeQuestionsRail> createState() => _HomeQuestionsRailState();
}

class _HomeQuestionsRailState extends State<HomeQuestionsRail> {
  final ScrollController _controller = ScrollController();
  bool _moreToTheRight = true;
  bool _moreToTheLeft = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_update);
    WidgetsBinding.instance.addPostFrameCallback((_) => _update());
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_update)
      ..dispose();
    super.dispose();
  }

  void _update() {
    if (!_controller.hasClients) return;
    final position = _controller.position;
    final right = position.pixels < position.maxScrollExtent - 1;
    final left = position.pixels > position.minScrollExtent + 1;
    if (right != _moreToTheRight || left != _moreToTheLeft) {
      setState(() {
        _moreToTheRight = right;
        _moreToTheLeft = left;
      });
    }
  }

  /// Scrolls one [HomeQuestionsRail.step] forward, or back when [forward]
  /// is false, clamped to the rail's ends.
  void _advance({required bool forward}) {
    if (!_controller.hasClients) return;
    final position = _controller.position;
    final step = forward ? HomeQuestionsRail.step : -HomeQuestionsRail.step;
    _controller.animateTo(
      (position.pixels + step).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      ),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Stack(
        children: <Widget>[
          ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: <Color>[
                if (_moreToTheLeft)
                  Colors.white.withValues(alpha: 0)
                else
                  Colors.white,
                Colors.white,
                Colors.white,
                if (_moreToTheRight)
                  Colors.white.withValues(alpha: 0)
                else
                  Colors.white,
              ],
              stops: const <double>[0, 0.18, 0.82, 1],
            ).createShader(bounds),
            blendMode: BlendMode.dstIn,
            child: ListView.separated(
              controller: _controller,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(20, 2, 64, 2),
              itemCount: widget.questions.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) =>
                  QuestionChip(text: widget.questions[index]),
            ),
          ),
          if (_moreToTheLeft)
            Positioned(
              left: 16,
              top: 4,
              child: RailArrow(
                key: HomeQuestionsRail.backKey,
                icon: Icons.chevron_left_rounded,
                label: 'Earlier questions',
                onTap: () => _advance(forward: false),
              ),
            ),
          if (_moreToTheRight)
            Positioned(
              right: 16,
              top: 4,
              child: RailArrow(
                key: HomeQuestionsRail.arrowKey,
                icon: Icons.chevron_right_rounded,
                label: 'More questions',
                onTap: () => _advance(forward: true),
              ),
            ),
        ],
      ),
    );
  }
}
