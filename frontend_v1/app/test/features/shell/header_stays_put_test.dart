import 'package:finance_app/features/shell/view/tab_app_bar.dart';
import 'package:finance_app/features/shell/view/tab_search_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'header_scroll_harness.dart';

/// Where the drag starts: below every header, above every composer.
const Offset _grab = Offset(187, 400);

/// Far enough to carry any of these headers off the top of a 812-pt phone.
const Offset _by = Offset(0, -300);

/// The vertical viewport of the surface on screen.
///
/// Filtered by axis on purpose: the Activity band's chips are a horizontal
/// `Scrollable` and come first in tree order, so "the first scrollable" would
/// name the wrong one.
ScrollPosition _content(WidgetTester tester) => tester
    .stateList<ScrollableState>(find.byType(Scrollable))
    .firstWhere((state) => state.position.axis == Axis.vertical)
    .position;

void main() {
  // The TL, scrolling the running app: "en el scroll el header no se queda
  // fijo y deberia de todas las paginas" — and the reason it matters, "es
  // una app mobile al final esto va a ir a mobile" (spec frontend/0024).
  //
  // Measured rather than eyeballed, the way spec 0021 argued the legend:
  // the header's own rect before and after, and the scroll offset as the
  // evidence that the drag did something. Against `develop` at 5cb9a40 the
  // Home case reported Rect.fromLTRB(0.0, -300.0, 375.0, -238.0) where it
  // expected Rect.fromLTRB(0.0, 0.0, 375.0, 62.0).
  group('a header', () {
    for (final surface in headerSurfaces()) {
      testWidgets('stays put while ${surface.name} scrolls', (tester) async {
        await surface.pump(tester);
        expect(surface.header, findsOneWidget);
        final before = tester.getRect(surface.header);
        final content = _content(tester);
        final offset = content.pixels;

        await tester.dragFrom(_grab, _by);
        await tester.pumpAndSettle();

        // Half of the claim: if nothing scrolled, a pinned header and a
        // scrolling one are the same picture and this test proves nothing.
        expect(
          content.pixels,
          greaterThan(offset),
          reason:
              '${surface.name} did not scroll, so the header being '
              'where it was says nothing',
        );
        expect(
          tester.getRect(surface.header),
          before,
          reason: "${surface.name}'s header moved with the content",
        );
      });
    }

    // The consequence the TL named: on Holdings the two controls a reader
    // reaches for while scrolling a long list were the first things the
    // list hid. Being on screen is not enough — they have to still work.
    testWidgets('keeps its controls usable after Holdings has scrolled', (
      tester,
    ) async {
      await pumpHoldings(tester);
      await tester.dragFrom(_grab, _by);
      await tester.pumpAndSettle();

      expect(find.byTooltip('Search Holdings'), findsOneWidget);
      expect(find.byTooltip('Filter Holdings'), findsOneWidget);
      await tester.tap(find.byTooltip('Search Holdings'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(TabAppBar),
          matching: find.byType(TabSearchField),
        ),
        findsOneWidget,
      );
    });

    // A header outside the scrollable is the mechanism; the rect assertions
    // above are its effect. Asserting the mechanism too is what makes a
    // regression name itself — a future `SliverAppBar` that is pinned would
    // satisfy this as well, and a header dropped back into a `ListView`
    // would not.
    testWidgets('is never a descendant of the scrollable it sits over', (
      tester,
    ) async {
      for (final surface in headerSurfaces()) {
        await surface.pump(tester);
        expect(
          find.descendant(of: find.byType(Viewport), matching: surface.header),
          findsNothing,
          reason: "${surface.name}'s header is inside a scrolling viewport",
        );
      }
    });
  });
}
