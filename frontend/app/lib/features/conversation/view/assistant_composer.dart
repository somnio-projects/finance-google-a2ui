import 'package:finance_app/theme/assistant_tokens.dart';
import 'package:finance_app/theme/home_tokens.dart';
import 'package:flutter/material.dart';

/// The composer: a 48 px rounded field, the mic and the send button
/// (spec frontend/0011 §2). [enabled] is false while a turn runs, which
/// greys the send button as the artboard's composing state does.
class AssistantComposer extends StatelessWidget {
  /// Creates the composer.
  const AssistantComposer({
    required this.controller,
    required this.onSend,
    required this.enabled,
    super.key,
  });

  /// The design's placeholder.
  static const String hint = 'Ask about your portfolio…';

  /// What the mic says when tapped (OD-5): drawn, not wired.
  static const String micNotice =
      'Voice input is not part of this preview yet.';

  /// The field's text.
  final TextEditingController controller;

  /// Sends the field's text.
  final VoidCallback onSend;

  /// Whether a send is accepted right now.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final tokens = HomeTokens.of(context);
    final assistant = AssistantTokens.of(context);
    return ColoredBox(
      color: tokens.header,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    border: Border.all(color: assistant.fieldBorder),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  alignment: Alignment.centerLeft,
                  child: TextField(
                    controller: controller,
                    enabled: enabled,
                    onSubmitted: (_) => onSend(),
                    style: TextStyle(fontSize: 14, color: tokens.text),
                    decoration: InputDecoration(
                      isCollapsed: true,
                      border: InputBorder.none,
                      hintText: hint,
                      hintStyle: TextStyle(
                        fontSize: 14,
                        color: assistant.placeholder,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _Round(
                color: assistant.mic,
                tooltip: 'Voice input',
                onTap: () =>
                    ScaffoldMessenger.of(context)
                        .showSnackBar(const SnackBar(content: Text(micNotice))),
                child: Icon(
                  Icons.mic_none_rounded,
                  size: 22,
                  color: assistant.micGlyph,
                ),
              ),
              const SizedBox(width: 8),
              _Round(
                color: enabled ? assistant.send : assistant.sendDisabled,
                tooltip: 'Send',
                onTap: enabled ? onSend : null,
                child: Icon(
                  Icons.play_arrow_rounded,
                  size: 24,
                  color: assistant.sendGlyph,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Round extends StatelessWidget {
  const _Round({
    required this.color,
    required this.tooltip,
    required this.onTap,
    required this.child,
  });

  final Color color;
  final String tooltip;
  final VoidCallback? onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) => Material(
    color: color,
    shape: const CircleBorder(),
    child: Tooltip(
      message: tooltip,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(width: 46, height: 46, child: Center(child: child)),
      ),
    ),
  );
}
