import 'package:finance_app/components/order_ticket_v2/order_ticket_v2_model.dart';
import 'package:finance_app/components/order_ticket_v2/order_ticket_v2_palette.dart';
import 'package:finance_app/components/order_ticket_v2/order_ticket_v2_text.dart';
import 'package:flutter/material.dart';

/// The design's `− 3 +` stepper.
///
/// **It adds nothing.** A tap sends [OrderTicketV2Line.increment] or
/// [OrderTicketV2Line.decrement] — the whole `legs` option value the backend
/// wrote for that move — through [onLegsChanged], unchanged (N-2, spec
/// backend/0031 OD-3). A side whose value is `null` is at the published
/// bound and renders disabled; so does every side when no host can honour an
/// edit.
///
/// Measured: a 1 px hairline with radius **9**, `-` and `+` cells **26 × 26**,
/// the count at least 32 px wide.
class OrderTicketV2Stepper extends StatelessWidget {
  /// Creates the stepper.
  const OrderTicketV2Stepper({
    required this.line,
    required this.isChanged,
    required this.onLegsChanged,
    super.key,
  });

  /// The stepper's corner radius, measured from the design.
  static const double radius = 9;

  /// The `-` and `+` cell, measured from the design.
  static const double cell = 26;

  /// What a screen reader hears on `+`. A step, not a share: the size of one
  /// tap is the asset's own step (0.01 BTC, one SOL), and a crypto leg holds
  /// units, not shares (GGU-149).
  static String increaseLabel(String symbol) => 'Increase $symbol by one step';

  /// …on `−`.
  static String decreaseLabel(String symbol) => 'Decrease $symbol by one step';

  /// …on the quantity between them.
  static String quantityLabel(String symbol) => '$symbol quantity';

  /// The leg stepped.
  final OrderTicketV2Line line;

  /// Whether the share count changed on the last render.
  final bool isChanged;

  /// Receives the `legs` value to send; null disables both sides.
  final ValueChanged<String>? onLegsChanged;

  @override
  Widget build(BuildContext context) {
    final palette = OrderTicketV2Palette.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: palette.stepBorder),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _Side(
              glyph: '−',
              label: decreaseLabel(line.symbol),
              value: line.decrement,
              onLegsChanged: onLegsChanged,
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 32),
              child: Semantics(
                container: true,
                label: quantityLabel(line.symbol),
                value: line.quantityDisplay,
                excludeSemantics: true,
                child: Text(
                  line.quantityDisplay,
                  textAlign: TextAlign.center,
                  style: OrderTicketV2Text.quantity(
                    isChanged ? palette.changed : palette.text,
                  ),
                ),
              ),
            ),
            _Side(
              glyph: '+',
              label: increaseLabel(line.symbol),
              value: line.increment,
              onLegsChanged: onLegsChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class _Side extends StatelessWidget {
  const _Side({
    required this.glyph,
    required this.label,
    required this.value,
    required this.onLegsChanged,
  });

  final String glyph;
  final String label;
  final String? value;
  final ValueChanged<String>? onLegsChanged;

  @override
  Widget build(BuildContext context) {
    final palette = OrderTicketV2Palette.of(context);
    final send = onLegsChanged;
    final target = value;
    final enabled = send != null && target != null;
    return Semantics(
      container: true,
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: enabled ? () => send(target) : null,
        child: ColoredBox(
          color: palette.stepSurface,
          child: SizedBox.square(
            dimension: OrderTicketV2Stepper.cell,
            child: Center(
              child: Text(
                glyph,
                style: OrderTicketV2Text.step(
                  enabled
                      ? palette.subText
                      : palette.subText.withValues(alpha: 0.4),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
