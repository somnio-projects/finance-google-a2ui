import 'package:finance_app/features/conversation/view/assistant_header.dart';
import 'package:finance_app/theme/assistant_tokens.dart';
import 'package:flutter/material.dart';

/// What the user said: an indigo bubble on the right, 20/20/6/20 corners,
/// at most 62 % of the column (spec frontend/0011 §2).
class UserBubble extends StatelessWidget {
  /// Creates the bubble with [text], verbatim.
  const UserBubble({required this.text, super.key});

  /// The words, as typed or as the chip read.
  final String text;

  @override
  Widget build(BuildContext context) {
    final assistant = AssistantTokens.of(context);
    return Align(
      alignment: Alignment.centerRight,
      child: FractionallySizedBox(
        widthFactor: 0.62,
        alignment: Alignment.centerRight,
        child: Align(
          alignment: Alignment.centerRight,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
            decoration: BoxDecoration(
              color: assistant.bubble,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomRight: Radius.circular(6),
                bottomLeft: Radius.circular(20),
              ),
            ),
            child: Text(
              text,
              style: TextStyle(fontSize: 14.5, color: assistant.bubbleText),
            ),
          ),
        ),
      ),
    );
  }
}

/// `Assistant`, under a 22 px avatar — and the three blinking dots while a
/// turn is still running.
class AssistantLabel extends StatelessWidget {
  /// Creates the label; [streaming] shows the dots.
  const AssistantLabel({required this.streaming, super.key});

  /// Whether a turn is in flight.
  final bool streaming;

  @override
  Widget build(BuildContext context) {
    final assistant = AssistantTokens.of(context);
    return Row(
      children: <Widget>[
        const AssistantAvatar(size: 22, radius: 7),
        const SizedBox(width: 8),
        Text(
          'Assistant',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: assistant.label,
          ),
        ),
        if (streaming) ...<Widget>[
          const SizedBox(width: 10),
          const StreamingDots(),
        ],
      ],
    );
  }
}

/// Three 6 px dots that blink in turn while the agent composes.
class StreamingDots extends StatefulWidget {
  /// Creates the dots.
  const StreamingDots({super.key});

  @override
  State<StreamingDots> createState() => _StreamingDotsState();
}

class _StreamingDotsState extends State<StreamingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final assistant = AssistantTokens.of(context);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => Row(
        children: <Widget>[
          for (var index = 0; index < 3; index++)
            Padding(
              padding: const EdgeInsets.only(right: 3),
              child: Opacity(
                // Each dot is a third of a cycle behind the last.
                opacity: 0.35 + 0.65 * _phase(index),
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: assistant.dot,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  double _phase(int index) {
    final shifted = (_controller.value - index / 3) % 1;
    return shifted < 0.5 ? shifted * 2 : (1 - shifted) * 2;
  }
}
