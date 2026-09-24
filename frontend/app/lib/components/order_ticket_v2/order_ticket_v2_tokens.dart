import 'package:finance_app/components/order_ticket_v2/order_ticket_v2_chrome.dart';
import 'package:finance_app/components/order_ticket_v2/order_ticket_v2_palette.dart';
import 'package:flutter/material.dart';

/// The multi-leg ticket's colours in each brightness, **measured from the
/// design**.
///
/// Every value was read out of `Catalog_OrderTicket.dc.html` — its `pal()`
/// table and the inline styles of its three states — by parsing the exported
/// page, not copied from a token list, and is pinned by
/// `order_ticket_v2_tokens_test.dart`. Where the catalog page and
/// `FlowC-Assistant.dc.html` disagree (the dark `Review order` fill, the dark
/// weight row), the **catalog page** wins: it is the component's contract and
/// the flow is one placement of it (spec frontend/0006 AC-16 took the same
/// side).
abstract final class OrderTicketV2Tokens {
  /// Light, as the `L1 · Light · 1024` artboard draws it.
  static const OrderTicketV2Palette light = OrderTicketV2Palette(
    surface: Color(0xFFFDFBFF),
    border: Color(0xFFEAE7F0),
    legSurface: Color(0xFFFDFBFF),
    legBorder: Color(0xFFEAE7F0),
    legAccent: Color(0xFFD8D5E2),
    changedSurface: Color(0xFFEEF0FF),
    changedBorder: Color(0xFFCDD2FF),
    changedAccent: Color(0xFF4F5DFF),
    text: Color(0xFF1A1B20),
    subText: Color(0xFF5F6169),
    mutedText: Color(0xFF8A8D96),
    stepBorder: Color(0xFFD8D5E2),
    stepSurface: Color(0xFFF5F3FB),
    track: Color(0xFFE6E2EF),
    fill: Color(0xFF4F5DFF),
    changed: Color(0xFF4F5DFF),
    label: Color(0xFF4F5DFF),
    dot: Color(0xFF7A5CFF),
    panelSurface: Color(0xFFF7F6FC),
    shiftSurface: Color(0xFFF5F3FB),
    negative: Color(0xFFC0362C),
  );

  /// Dark, as the `D1 · Dark · 1024` artboard draws it.
  ///
  /// The geometry is pixel-identical between the artboards — only the
  /// palette changes — which is why one layout serves both. `mutedText` and
  /// `dot` are the **same** in both: the designer holds them across themes.
  static const OrderTicketV2Palette dark = OrderTicketV2Palette(
    surface: Color(0xFF15161C),
    border: Color(0xFF24252D),
    legSurface: Color(0xFF191A21),
    legBorder: Color(0xFF2A2B33),
    legAccent: Color(0xFF3A3B44),
    changedSurface: Color(0xFF20223A),
    changedBorder: Color(0xFF3A3B6E),
    changedAccent: Color(0xFF7A83FF),
    text: Color(0xFFE5E1E9),
    subText: Color(0xFFA4A6B0),
    mutedText: Color(0xFF8A8D96),
    stepBorder: Color(0xFF33343D),
    stepSurface: Color(0xFF1F2028),
    track: Color(0xFF2A2B33),
    fill: Color(0xFF7A83FF),
    changed: Color(0xFFB9C0FF),
    label: Color(0xFFB9C0FF),
    dot: Color(0xFF7A5CFF),
    panelSurface: Color(0xFF101017),
    shiftSurface: Color(0xFF15161C),
    negative: Color(0xFFFF6B5E),
  );

  /// The state chrome, light.
  ///
  /// `buttonSurface`/`buttonText` are the artboard's **blocked** `Review
  /// order` — `#d8d5e2` on `#9a97a8` — because a button nothing can be
  /// reviewed through is drawn as the design draws one that cannot be
  /// pressed (spec frontend/0013 OD-3).
  static const OrderTicketV2Chrome chromeLight = OrderTicketV2Chrome(
    pillText: Color(0xFF3A2F70),
    pillSurface: Color(0xFFEAE7F5),
    recomputedPillText: Color(0xFF3A2F70),
    recomputedPillSurface: Color(0xFFE2E0FB),
    recomputedPillBorder: Color(0xFFCDD2FF),
    blockedPillText: Color(0xFF8F2A22),
    blockedPillSurface: Color(0xFFFBE4E1),
    noticeSurface: Color(0xFFFBE9E7),
    noticeBorder: Color(0xFFF2CCC7),
    noticeIcon: Color(0xFFC0362C),
    noticeIconText: Color(0xFFFFFFFF),
    noticeText: Color(0xFF8F2A22),
    buttonSurface: Color(0xFFD8D5E2),
    buttonText: Color(0xFF9A97A8),
  );

  /// The state chrome, dark.
  static const OrderTicketV2Chrome chromeDark = OrderTicketV2Chrome(
    pillText: Color(0xFFC9CBFF),
    pillSurface: Color(0xFF232036),
    recomputedPillText: Color(0xFFC9CBFF),
    recomputedPillSurface: Color(0xFF2A2748),
    recomputedPillBorder: Color(0xFF3F3A68),
    blockedPillText: Color(0xFFFFB0A8),
    blockedPillSurface: Color(0xFF3A1A16),
    noticeSurface: Color(0xFF2A1512),
    noticeBorder: Color(0xFF4A231E),
    noticeIcon: Color(0xFFFF6B5E),
    noticeIconText: Color(0xFF3A0D09),
    noticeText: Color(0xFFF5A89F),
    buttonSurface: Color(0xFF2A2B33),
    buttonText: Color(0xFF6A6B74),
  );

  /// The palette for [brightness].
  static OrderTicketV2Palette forBrightness(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;

  /// The chrome for [brightness].
  static OrderTicketV2Chrome chromeFor(Brightness brightness) =>
      brightness == Brightness.dark ? chromeDark : chromeLight;
}
