import 'package:finance_app/features/conversation/view/assistant_mic_button.dart';
import 'package:finance_app/features/conversation/view/composer_round_button.dart';
import 'package:finance_app/theme/assistant_tokens.dart';
import 'package:finance_app/theme/home_tokens.dart';
import 'package:flutter/material.dart';

/// The composer: a 48 px rounded field, the mic and the send button
/// (spec frontend/0011 §2). [enabled] is false while a turn runs, which
/// greys the send button as the artboard's composing state does.
///
/// The mic used to be drawn here with a snackbar saying it was not wired
/// (0011 OD-5). It is wired now, and it owns its own states, so it is
/// [AssistantMicButton] and this file no longer knows what it does
/// (spec frontend/0022).
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

  /// The field's text. Typed into, and dictated into (spec 0022 OD-1).
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
              const AssistantMicButton(),
              const SizedBox(width: 8),
              ComposerRoundButton(
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
