import 'package:finance_app/features/home/view/home_questions.dart';
import 'package:finance_app/theme/home_tokens.dart';
import 'package:flutter/material.dart';

/// The horizontal rail of question chips, with what the design's flat row
/// lacked: a fading right edge while more chips are off-screen, and a round
/// arrow that scrolls them into view — so it reads as a slider, not a cut.
class HomeQuestionsRail extends StatefulWidget {
  /// Creates the rail.
  const HomeQuestionsRail({required this.questions, super.key});

  /// Where the arrow lives, for tests.
  static const Key arrowKey = Key('questions-rail-arrow');

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
    final more = position.pixels < position.maxScrollExtent - 1;
    if (more != _moreToTheRight) setState(() => _moreToTheRight = more);
  }

  void _advance() {
    if (!_controller.hasClients) return;
    final position = _controller.position;
    final target = position.pixels + HomeQuestionsRail.step;
    _controller.animateTo(
      target > position.maxScrollExtent ? position.maxScrollExtent : target,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = HomeTokens.of(context);
    return SizedBox(
      height: 44,
      child: Stack(
        children: <Widget>[
          ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: <Color>[
                Colors.white,
                Colors.white,
                if (_moreToTheRight)
                  Colors.white.withValues(alpha: 0)
                else
                  Colors.white,
              ],
              stops: const <double>[0, 0.82, 1],
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
          if (_moreToTheRight)
            Positioned(
              right: 16,
              top: 4,
              child: Semantics(
                button: true,
                label: 'More questions',
                child: Material(
                  color: tokens.chip,
                  shape: CircleBorder(
                    side: BorderSide(color: tokens.chipBorder),
                  ),
                  elevation: 1,
                  child: InkWell(
                    key: HomeQuestionsRail.arrowKey,
                    customBorder: const CircleBorder(),
                    onTap: _advance,
                    child: SizedBox(
                      width: 36,
                      height: 36,
                      child: Icon(
                        Icons.chevron_right_rounded,
                        size: 22,
                        color: tokens.chipText,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
