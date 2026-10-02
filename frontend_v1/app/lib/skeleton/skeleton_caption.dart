import 'package:finance_app/theme/skeleton_tokens.dart';
import 'package:flutter/material.dart';

/// The line under a loading card: an 11 px ring with a gap, turning, and the
/// words beside it — `get_holdings()…` in mono on the catalog pages,
/// `Loading…` in the UI face on Home.
///
/// The words are chrome, not data: they name the tool or the act of waiting,
/// never a figure, so they are the client's to own (N-9 is about the
/// backend's sentences, and none has arrived yet).
class SkeletonCaption extends StatefulWidget {
  /// Creates the caption.
  const SkeletonCaption({required this.text, this.mono = false, super.key});

  /// One turn of the ring.
  static const Duration period = Duration(seconds: 1);

  /// The ring's diameter, from `width:11px;height:11px`.
  static const double ringSize = 11;

  /// The words.
  final String text;

  /// `Roboto Mono` on the catalog pages, the UI face on Home.
  final bool mono;

  @override
  State<SkeletonCaption> createState() => _SkeletonCaptionState();
}

class _SkeletonCaptionState extends State<SkeletonCaption>
    with SingleTickerProviderStateMixin {
  late final AnimationController _turn = AnimationController(
    vsync: this,
    duration: SkeletonCaption.period,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _turn
        ..stop()
        ..value = 0;
    } else if (!_turn.isAnimating) {
      _turn.repeat();
    }
  }

  @override
  void dispose() {
    _turn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = SkeletonTokens.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        RotationTransition(
          turns: _turn,
          child: SizedBox.square(
            dimension: SkeletonCaption.ringSize,
            // Three quarters of a ring: the CSS's `border-top-color:
            // transparent`, drawn by the one Material widget that already
            // paints a stroked arc.
            child: CircularProgressIndicator(
              value: 0.75,
              strokeWidth: 1.5,
              color: tokens.caption,
              backgroundColor: Colors.transparent,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          widget.text,
          style: TextStyle(
            fontSize: widget.mono ? 10.5 : 11.5,
            fontFamily: widget.mono ? 'Roboto Mono' : null,
            color: tokens.caption,
          ),
        ),
      ],
    );
  }
}
