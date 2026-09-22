import 'package:finance_app/features/conversation/bloc/voice_input_bloc.dart';
import 'package:finance_app/features/conversation/view/voice_notice.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The two side effects a dictation session has outside its own bloc.
///
/// A bloc cannot type into a `TextEditingController` and cannot show a
/// snackbar, so the effects live here, over [child], and the bloc stays a
/// state machine (spec frontend/0022).
class VoiceInputListener extends StatelessWidget {
  /// Wraps [child] with the composer's [controller] in scope.
  const VoiceInputListener({
    required this.controller,
    required this.child,
    super.key,
  });

  /// The composer's field. Dictation fills it; it never sends (OD-1).
  final TextEditingController controller;

  /// The composer.
  final Widget child;

  @override
  Widget build(BuildContext context) => MultiBlocListener(
    listeners: <BlocListener<VoiceInputBloc, VoiceInputState>>[
      BlocListener<VoiceInputBloc, VoiceInputState>(
        listenWhen: (previous, current) =>
            previous.transcript != current.transcript,
        listener: (context, state) => _fill(state.transcript),
      ),
      BlocListener<VoiceInputBloc, VoiceInputState>(
        // On the counter, not on the failure: two refusals of the same kind
        // are two equal states, and a listener keyed on the value would show
        // one snackbar and swallow the second tap (spec 0022 OD-4, AC-7).
        listenWhen: (previous, current) => previous.notices != current.notices,
        // `failure` is non-null whenever `notices` advances — `noticing` is
        // the only transition that touches either, and it sets both.
        listener: (context, state) => ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(voiceNotice(state.failure!)))),
      ),
    ],
    child: child,
  );

  /// Replaces the field with [transcript], caret after the last word.
  ///
  /// Replacing rather than appending is the contract of `SpeechHeard`: the
  /// engine re-reports the whole utterance as it revises it.
  void _fill(String transcript) => controller.value = TextEditingValue(
    text: transcript,
    selection: TextSelection.collapsed(offset: transcript.length),
  );
}
