import 'package:finance_app/components/order_ticket_v2/order_ticket_v2_palette.dart';
import 'package:finance_app/components/order_ticket_v2/order_ticket_v2_text.dart';
import 'package:flutter/material.dart';

/// The design's weight bar: a 4 px track, a fill, a 14 px handle, the weight.
///
/// The fill's width is the one place this component uses a raw member —
/// `weight.value` through `ViewPayload.geometry` — and it is a **width**, the
/// use ADR-K reserves it for (N-4, ADR-L D-14). The figure beside it is the
/// backend's `weight.display`, verbatim.
///
/// **It is not a slider.** The design draws a handle, and dragging one would
/// turn a pixel into a share count — arithmetic this client may not perform
/// (N-2). The stepper is the control; the bar shows what the stepper did
/// (spec frontend/0013 OD-1).
class OrderTicketV2WeightBar extends StatelessWidget {
  /// Creates the bar.
  const OrderTicketV2WeightBar({
    required this.fraction,
    required this.display,
    required this.isChanged,
    required this.ringColor,
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
                return Stack(
                  alignment: Alignment.centerLeft,
                  children: <Widget>[
                    _Track(color: palette.track),
                    SizedBox(
                      width: width,
                      child: _Track(color: fill),
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

class _Track extends StatelessWidget {
  const _Track({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(
        OrderTicketV2WeightBar.trackHeight / 2,
      ),
    ),
    child: const SizedBox(
      height: OrderTicketV2WeightBar.trackHeight,
      width: double.infinity,
    ),
  );
}
