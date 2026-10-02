import 'package:finance_app/features/shell/view/pinned_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';
import 'header_scroll_harness.dart';

/// The inset the design's phone reports at the top, in logical pixels.
const double _statusBar = 44;

/// The child's own height, so the band's is readable as inset + this.
const double _childHeight = 40;

const Color _band = Color(0xFF123456);

void main() {
  group(PinnedHeader, () {
    Future<void> pumpBand(WidgetTester tester, {BoxBorder? border}) =>
        tester.pumpApp(
          MediaQuery(
            data: const MediaQueryData(
              padding: EdgeInsets.only(top: _statusBar),
            ),
            // In a Column, as every surface uses it: on its own as a
            // MaterialApp's home it would stretch to the window and the
            // band's height would say nothing.
            child: Column(
              children: <Widget>[
                PinnedHeader(
                  color: _band,
                  border: border,
                  child: const SizedBox(height: _childHeight, width: 200),
                ),
              ],
            ),
          ),
        );

    // The half that only starts to matter once the header never moves: a
    // scrolling header met the status bar at offset 0 and then left, a
    // pinned one meets it for the whole session (spec frontend/0024 OD-4).
    testWidgets('holds its child clear of the top safe-area inset', (
      tester,
    ) async {
      await pumpBand(tester);
      expect(tester.getRect(find.byType(SizedBox)).top, _statusBar);
    });

    // And the strip the inset opens up is the band's colour, not the page
    // showing through — which is why the SafeArea is INSIDE the decoration,
    // the same way ShellTabBar does it at the bottom edge.
    testWidgets('paints the inset strip in the band colour', (tester) async {
      await pumpBand(tester);
      final rect = tester.getRect(find.byType(PinnedHeader));
      expect(rect.top, 0);
      expect(rect.height, _statusBar + _childHeight);
      final decorated = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(PinnedHeader),
          matching: find.byType(DecoratedBox),
        ),
      );
      expect((decorated.decoration as BoxDecoration).color, _band);
    });

    testWidgets('draws the rule under the band when the design has one', (
      tester,
    ) async {
      const border = Border(bottom: BorderSide(color: _band));
      await pumpBand(tester, border: border);
      final decorated = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(PinnedHeader),
          matching: find.byType(DecoratedBox),
        ),
      );
      expect((decorated.decoration as BoxDecoration).border, border);
    });

    // The other half of "do not make it worse": a pinned header must not
    // turn a surface that fits into one that scrolls, or leave a scrollbar
    // over nothing (spec frontend/0024 AC-6).
    testWidgets('leaves a surface that fits with nothing to scroll', (
      tester,
    ) async {
      await tester.pumpApp(const _Short(), surfaceSize: Size(phone.width, 400));
      final position = tester
          .state<ScrollableState>(find.byType(Scrollable))
          .position;
      expect(position.maxScrollExtent, 0);
      expect(tester.getRect(find.byType(PinnedHeader)).top, 0);
    });
  });
}

/// A surface in the shape every tab now takes, with content that fits.
class _Short extends StatelessWidget {
  const _Short();

  @override
  Widget build(BuildContext context) => Column(
    children: <Widget>[
      const PinnedHeader(
        color: _band,
        child: SizedBox(height: _childHeight, width: 200),
      ),
      Expanded(
        child: ListView(
          padding: EdgeInsets.zero,
          children: const <Widget>[SizedBox(height: 60)],
        ),
      ),
    ],
  );
}
