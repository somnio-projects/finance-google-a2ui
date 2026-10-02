import 'package:finance_app/features/conversation/bloc/voice_input_bloc.dart';
import 'package:finance_app/features/conversation/view/composer_round_button.dart';
import 'package:finance_app/features/conversation/view/voice_notice.dart';
import 'package:finance_app/theme/assistant_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The composer's microphone, in its three states (spec frontend/0023).
///
/// **It is never inert.** On a build with no engine it still answers a tap,
/// with a tooltip and a sentence that say why — the defect spec 0021 OD-2
/// recorded was a control that did nothing, and a disabled mic would be the
/// same defect wearing a grey coat.
///
/// **No colour is invented here** (spec 0023 OD-6). There is no artboard for
/// a listening microphone, so the live state borrows the send button's
/// active pair, which is already this composer's "this control is working"
/// palette. `AssistantTokens` gains no field.
class AssistantMicButton extends StatelessWidget {
  /// Creates the mic control.
  const AssistantMicButton({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = AssistantTokens.of(context);
    final status = context.watch<VoiceInputBloc>().state.status;
    final listening = status == VoiceInputStatus.listening;
    return ComposerRoundButton(
      color: listening ? tokens.send : tokens.mic,
      tooltip: switch (status) {
        VoiceInputStatus.unavailable => voiceUnavailableTooltip,
        VoiceInputStatus.idle => voiceIdleTooltip,
        VoiceInputStatus.listening => voiceListeningTooltip,
      },
      onTap: () => context.read<VoiceInputBloc>().add(
        listening ? VoiceInputStopped() : VoiceInputStarted(),
      ),
      child: Icon(
        listening ? Icons.stop_rounded : Icons.mic_none_rounded,
        size: 22,
        color: listening ? tokens.sendGlyph : tokens.micGlyph,
      ),
    );
  }
}
