import 'package:finance_app/components/order_ticket_v2/order_ticket_v2_tokens.dart';
import 'package:flutter/material.dart';

/// The ticket's state chrome — pills, the validation notice, the buttons.
///
/// Split from `OrderTicketV2Palette` for the file budget, along the seam the
/// design itself draws: these colours change with the ticket's **state**
/// (editable, recomputed, blocked), the palette's with its **brightness**
/// alone. Measured from the same two artboards.
@immutable
class OrderTicketV2Chrome {
  /// Creates the chrome. Every colour is required.
  const OrderTicketV2Chrome({
    required this.pillText,
    required this.pillSurface,
    required this.recomputedPillText,
    required this.recomputedPillSurface,
    required this.recomputedPillBorder,
    required this.blockedPillText,
    required this.blockedPillSurface,
    required this.noticeSurface,
    required this.noticeBorder,
    required this.noticeIcon,
    required this.noticeIconText,
    required this.noticeText,
    required this.buttonSurface,
    required this.buttonText,
  });

  /// The chrome for the brightness [context] is themed in.
  static OrderTicketV2Chrome of(BuildContext context) =>
      OrderTicketV2Tokens.chromeFor(Theme.of(context).brightness);

  /// The `editable` pill's text.
  final Color pillText;

  /// The `editable` pill's fill.
  final Color pillSurface;

  /// The recomputed pill's text.
  final Color recomputedPillText;

  /// The recomputed pill's fill.
  final Color recomputedPillSurface;

  /// The recomputed pill's hairline.
  final Color recomputedPillBorder;

  /// The `blocked` pill's text.
  final Color blockedPillText;

  /// The `blocked` pill's fill.
  final Color blockedPillSurface;

  /// The validation notice's fill.
  final Color noticeSurface;

  /// The validation notice's hairline.
  final Color noticeBorder;

  /// The `!` disc.
  final Color noticeIcon;

  /// The `!` glyph on it.
  final Color noticeIconText;

  /// The validation sentence.
  final Color noticeText;

  /// `Review order`, as the design draws it when nothing can be reviewed —
  /// the only state this showcase has (spec frontend/0013 OD-3).
  final Color buttonSurface;

  /// Its label, and `Save as draft`.
  final Color buttonText;
}
