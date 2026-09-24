import 'package:finance_app/components/order_ticket_v2/order_ticket_v2_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pins every value measured off the catalog page's two artboards.
///
/// A literal is the point: if one drifts, someone changed a colour and has
/// to say so. `changed` is the indigo the ticket highlights recomputed
/// values in — `#4F5DFF` light, `#B9C0FF` dark — as the design's `pal()`
/// names it.
void main() {
  group('OrderTicketV2Tokens', () {
    test('light matches the L1 artboard', () {
      const light = OrderTicketV2Tokens.light;
      expect(light.surface, const Color(0xFFFDFBFF));
      expect(light.border, const Color(0xFFEAE7F0));
      expect(light.legAccent, const Color(0xFFD8D5E2));
      expect(light.changedSurface, const Color(0xFFEEF0FF));
      expect(light.changedBorder, const Color(0xFFCDD2FF));
      expect(light.changedAccent, const Color(0xFF4F5DFF));
      expect(light.text, const Color(0xFF1A1B20));
      expect(light.subText, const Color(0xFF5F6169));
      expect(light.mutedText, const Color(0xFF8A8D96));
      expect(light.stepBorder, const Color(0xFFD8D5E2));
      expect(light.stepSurface, const Color(0xFFF5F3FB));
      expect(light.track, const Color(0xFFE6E2EF));
      expect(light.fill, const Color(0xFF4F5DFF));
      expect(light.changed, const Color(0xFF4F5DFF));
      expect(light.dot, const Color(0xFF7A5CFF));
      expect(light.panelSurface, const Color(0xFFF7F6FC));
      expect(light.negative, const Color(0xFFC0362C));
    });

    test('dark matches the D1 artboard', () {
      const dark = OrderTicketV2Tokens.dark;
      expect(dark.surface, const Color(0xFF15161C));
      expect(dark.border, const Color(0xFF24252D));
      expect(dark.legSurface, const Color(0xFF191A21));
      expect(dark.legBorder, const Color(0xFF2A2B33));
      expect(dark.changedSurface, const Color(0xFF20223A));
      expect(dark.changedBorder, const Color(0xFF3A3B6E));
      expect(dark.changedAccent, const Color(0xFF7A83FF));
      expect(dark.text, const Color(0xFFE5E1E9));
      expect(dark.subText, const Color(0xFFA4A6B0));
      expect(dark.fill, const Color(0xFF7A83FF));
      expect(dark.changed, const Color(0xFFB9C0FF));
      expect(dark.label, const Color(0xFFB9C0FF));
      expect(dark.panelSurface, const Color(0xFF101017));
      expect(dark.shiftSurface, const Color(0xFF15161C));
      expect(dark.negative, const Color(0xFFFF6B5E));
    });

    test('the state chrome matches both artboards', () {
      const light = OrderTicketV2Tokens.chromeLight;
      expect(light.pillText, const Color(0xFF3A2F70));
      expect(light.pillSurface, const Color(0xFFEAE7F5));
      expect(light.recomputedPillSurface, const Color(0xFFE2E0FB));
      expect(light.blockedPillText, const Color(0xFF8F2A22));
      expect(light.blockedPillSurface, const Color(0xFFFBE4E1));
      expect(light.noticeSurface, const Color(0xFFFBE9E7));
      expect(light.noticeBorder, const Color(0xFFF2CCC7));
      expect(light.noticeIcon, const Color(0xFFC0362C));
      expect(light.buttonSurface, const Color(0xFFD8D5E2));
      expect(light.buttonText, const Color(0xFF9A97A8));
      const dark = OrderTicketV2Tokens.chromeDark;
      expect(dark.pillText, const Color(0xFFC9CBFF));
      expect(dark.pillSurface, const Color(0xFF232036));
      expect(dark.blockedPillText, const Color(0xFFFFB0A8));
      expect(dark.noticeSurface, const Color(0xFF2A1512));
      expect(dark.noticeText, const Color(0xFFF5A89F));
      expect(dark.buttonSurface, const Color(0xFF2A2B33));
      expect(dark.buttonText, const Color(0xFF6A6B74));
    });

    test('picks the palette and chrome by brightness', () {
      expect(
        OrderTicketV2Tokens.forBrightness(Brightness.light),
        OrderTicketV2Tokens.light,
      );
      expect(
        OrderTicketV2Tokens.forBrightness(Brightness.dark),
        OrderTicketV2Tokens.dark,
      );
      expect(
        OrderTicketV2Tokens.chromeFor(Brightness.light),
        OrderTicketV2Tokens.chromeLight,
      );
      expect(
        OrderTicketV2Tokens.chromeFor(Brightness.dark),
        OrderTicketV2Tokens.chromeDark,
      );
    });

    test('the two themes agree with the chart palette on the shared roles', () {
      // The card and the accent are the app's, measured independently.
      expect(OrderTicketV2Tokens.light.surface, const Color(0xFFFDFBFF));
      expect(OrderTicketV2Tokens.dark.surface, const Color(0xFF15161C));
      expect(OrderTicketV2Tokens.light.fill, const Color(0xFF4F5DFF));
      expect(OrderTicketV2Tokens.dark.fill, const Color(0xFF7A83FF));
    });
  });
}
