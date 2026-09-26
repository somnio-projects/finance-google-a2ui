import 'package:finance_app/components/order_ticket_v2/order_ticket_v2_palette.dart';
import 'package:finance_app/components/order_ticket_v2/order_ticket_v2_text.dart';
import 'package:finance_app/components/order_ticket_v2/order_ticket_v2_track.dart';
import 'package:finance_app/components/order_ticket_v2/order_ticket_v2_track_gesture.dart';
import 'package:flutter/material.dart';

/// The design's weight bar: a 4 px track, a fill, a 14 px handle, the weight.
///
/// The fill's width is the one place this component uses a raw member —
/// `weight.value` through `ViewPayload.geometry` — and it is a **width**, the
/// use ADR-K reserves it for (N-4, ADR-L D-14). The figure beside it is the
/// backend's `weight.display`, verbatim.
///
/// **It became a slider, and the sentence it used to carry is why it could
/// not be one before:** *"dragging one would turn a pixel into a share count
/// — arithmetic this client may not perform (N-2)."* True of the contract as
/// it stood; not true of `lines[].stops`, a list of whole `legs` values the
/// backend wrote (backend spec 0050). A drag picks the stop whose band it
/// landed in, so a pixel becomes a list index and never a quantity.
///
/// The thumb is drawn at `weight`, not at the stop index. The two agree to
/// within one stride — the ladder walks weight — and where they differ the
/// weight wins, because it is the number printed beside it.
class OrderTicketV2WeightBar extends StatelessWidget {
  /// Creates the bar.
  const OrderTicketV2WeightBar({
    required this.fraction,
    required this.display,
    required this.isChanged,
    required this.ringColor,
    this.stops = const <String>[],
    this.onLegsChanged,
    super.key,
  });

  /// The track's height, measured from the design.
  static const double trackHeight = 4;

  /// The handle's diameter, measured from the design.
  static const double handleSize = 14;

  /// The fill, `0..1`; a canvas coordinate, never shown.
  final double fraction;

  /// The weight as the backend formatted it.
  final String display;

  /// Whether the weight's string changed on the last render.
  final bool isChanged;

  /// The handle's 2 px ring — the surface the bar sits on.
  final Color ringColor;

  /// The `legs` values a drag may land on, written by the backend and sent
  /// back unchanged. Empty or single means the track is not draggable.
  final List<String> stops;

  /// Where a drag goes. Null when no host can honour an edit, which is the
  /// same condition that disables the stepper.
  final ValueChanged<String>? onLegsChanged;

  @override
  Widget build(BuildContext context) {
    final palette = OrderTicketV2Palette.of(context);
    final fill = isChanged ? palette.changed : palette.fill;
    final clamped = fraction.clamp(0.0, 1.0);
    return Row(
      children: <Widget>[
        Expanded(
          child: SizedBox(
            height: handleSize,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth * clamped;
                final send = OrderTicketV2TrackGesture(
                  stops: stops,
                  onLegsChanged: onLegsChanged,
                ).on(constraints.maxWidth);
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: send == null
                      ? null
                      : (details) => send(details.localPosition),
                  onHorizontalDragUpdate: send == null
                      ? null
                      : (details) => send(details.localPosition),
                  child: Stack(
                    alignment: Alignment.centerLeft,
                    children: <Widget>[
                      OrderTicketV2Track(color: palette.track),
                      SizedBox(
                        width: width,
                        child: OrderTicketV2Track(color: fill),
                      ),
                      Positioned(
                        left: width - handleSize / 2,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: fill,
                            shape: BoxShape.circle,
                            border: Border.all(color: ringColor, width: 2),
                          ),
                          child: const SizedBox.square(dimension: handleSize),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(width: 9),
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 34),
          child: Text(
            display,
            textAlign: TextAlign.right,
            style: OrderTicketV2Text.weight(
              isChanged ? palette.changed : palette.subText,
            ),
          ),
        ),
      ],
    );
  }
}
