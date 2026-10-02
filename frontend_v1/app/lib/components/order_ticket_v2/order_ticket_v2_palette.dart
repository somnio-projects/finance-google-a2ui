import 'package:finance_app/components/order_ticket_v2/order_ticket_v2_tokens.dart';
import 'package:flutter/material.dart';

/// The colours the multi-leg ticket is drawn with, in one brightness.
///
/// A plain immutable class rather than a `ThemeExtension`, for the reason
/// `TaxLotPalette` gives: registering an extension means editing `AppTheme`,
/// and *adding a component edits no existing file* (ADR-L D-3). [of] reads
/// the brightness the theme already carries, which needs nothing registered.
///
/// Every value is measured from `Catalog_OrderTicket.dc.html`'s `pal()` and
/// its two artboards; the state chrome — pills, notice, buttons — is
/// `OrderTicketV2Chrome`, split for the file budget.
@immutable
class OrderTicketV2Palette {
  /// Creates a palette. Every colour is required — a ticket with a missing
  /// role would fall back to something nobody chose.
  const OrderTicketV2Palette({
    required this.surface,
    required this.border,
    required this.legSurface,
    required this.legBorder,
    required this.legAccent,
    required this.changedSurface,
    required this.changedBorder,
    required this.changedAccent,
    required this.text,
    required this.subText,
    required this.mutedText,
    required this.stepBorder,
    required this.stepSurface,
    required this.track,
    required this.fill,
    required this.changed,
    required this.label,
    required this.dot,
    required this.panelSurface,
    required this.shiftSurface,
    required this.negative,
  });

  /// The palette for the brightness [context] is themed in.
  static OrderTicketV2Palette of(BuildContext context) =>
      OrderTicketV2Tokens.forBrightness(Theme.of(context).brightness);

  /// The outer card.
  final Color surface;

  /// The hairline around the card and the impact panel.
  final Color border;

  /// A leg's card, at rest.
  final Color legSurface;

  /// A leg's hairline, at rest.
  final Color legBorder;

  /// The 3 px rail down a leg's left edge, at rest.
  final Color legAccent;

  /// A leg's card, and the impact panel, after its figures moved.
  final Color changedSurface;

  /// Their hairline after a move.
  final Color changedBorder;

  /// The rail of the leg that was stepped.
  final Color changedAccent;

  /// Primary text: tickers, amounts, values.
  final Color text;

  /// Secondary text: the price beside a ticker, a weight at rest.
  final Color subText;

  /// Captions: the header, the panel's labels, `recomputed on edit`.
  final Color mutedText;

  /// The stepper's hairline.
  final Color stepBorder;

  /// The stepper's `-` and `+` buttons.
  final Color stepSurface;

  /// The weight bar's track.
  final Color track;

  /// The weight bar's fill and handle, at rest.
  final Color fill;

  /// A figure, a fill or a weight whose string changed on the last render —
  /// the indigo the design highlights recomputed values in.
  final Color changed;

  /// The `ORDER IMPACT` caption.
  final Color label;

  /// The 5 px dot beside it, and the `· sim` marker.
  final Color dot;

  /// The impact panel at rest.
  final Color panelSurface;

  /// The `Portfolio weight` row inside the panel.
  final Color shiftSurface;

  /// Cash remaining when the draft is over it.
  final Color negative;
}
