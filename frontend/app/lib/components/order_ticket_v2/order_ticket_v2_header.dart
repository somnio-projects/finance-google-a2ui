import 'package:finance_app/components/order_ticket_v2/order_ticket_v2_chrome.dart';
import 'package:finance_app/components/order_ticket_v2/order_ticket_v2_model.dart';
import 'package:finance_app/components/order_ticket_v2/order_ticket_v2_palette.dart';
import 'package:finance_app/components/order_ticket_v2/order_ticket_v2_text.dart';
import 'package:flutter/material.dart';

/// `DRAFT ORDER · BUY · 3 LEGS` and the pill beside it.
///
/// The title is the backend's `title`, drawn in the design's uppercase
/// `subtag` — `text-transform` is typography, not a rewrite, the same call
/// `OrderTicketImpact` makes for its caption. The pill is the backend's
/// `badge` (`editable` / `blocked`) until a leg has just been stepped, when
/// it names that leg. The design's pill reads `NVDA +$2,000`; the signed
/// delta is arithmetic this client may not do (N-2), so the pill carries the
/// symbol and the word, and spec frontend/0013 OD-2 records the gap.
class OrderTicketV2Header extends StatelessWidget {
  /// Creates the header.
  const OrderTicketV2Header({
    required this.data,
    required this.stepped,
    super.key,
  });

  /// What the pill says after a step, beside the leg's ticker.
  static const String recomputedWord = 'recomputed';

  /// The ticket described.
  final OrderTicketV2Data data;

  /// The legs whose share count moved on the last render.
  final Set<String> stepped;

  @override
  Widget build(BuildContext context) {
    final palette = OrderTicketV2Palette.of(context);
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            data.title.toUpperCase(),
            style: OrderTicketV2Text.caption(palette.mutedText),
          ),
        ),
        const SizedBox(width: 8),
        _Pill(data: data, stepped: stepped),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.data, required this.stepped});

  final OrderTicketV2Data data;
  final Set<String> stepped;

  @override
  Widget build(BuildContext context) {
    final chrome = OrderTicketV2Chrome.of(context);
    final palette = OrderTicketV2Palette.of(context);
    if (data.isBlocked) {
      return _Chip(
        text: data.badge,
        color: chrome.blockedPillText,
        surface: chrome.blockedPillSurface,
      );
    }
    if (stepped.isEmpty) {
      return _Chip(
        text: data.badge,
        color: chrome.pillText,
        surface: chrome.pillSurface,
      );
    }
    return _Chip(
      text: '${stepped.join(', ')} · ${OrderTicketV2Header.recomputedWord}',
      color: chrome.recomputedPillText,
      surface: chrome.recomputedPillSurface,
      border: chrome.recomputedPillBorder,
      dot: palette.changed,
    );
  }
}

/// The design's pill: radius 20, padding `2px 9px`, an optional 5 px dot.
class _Chip extends StatelessWidget {
  const _Chip({
    required this.text,
    required this.color,
    required this.surface,
    this.border,
    this.dot,
  });

  final String text;
  final Color color;
  final Color surface;
  final Color? border;
  final Color? dot;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Status',
      value: text,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: surface,
          border: border == null ? null : Border.all(color: border!),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (dot case final Color dotColor) ...<Widget>[
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                  child: const SizedBox.square(dimension: 5),
                ),
                const SizedBox(width: 4),
              ],
              Text(text, style: OrderTicketV2Text.pill(color)),
            ],
          ),
        ),
      ),
    );
  }
}
