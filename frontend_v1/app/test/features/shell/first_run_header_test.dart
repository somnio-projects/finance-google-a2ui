/// AC-8 — the three first-run skeletons pin their header too.
///
/// Split from `header_stays_put_test.dart` for the 150-line budget, and
/// written because the review found AC-8 asserted by nothing that could have
/// been red: `headerSurfaces()` lists only the six **loaded** surfaces, and
/// the golden shots the spec pointed at are taken at offset 0 — the one
/// offset at which a pinned header and a scrolling one are indistinguishable
/// (spec frontend/0024 §2). Revert any skeleton to `ListView(children:
/// [header, …])` and every other check in this suite stays green.
///
/// A skeleton needs no bloc and no repository, so the assertion is the
/// mechanism alone: the header is not inside the scrollable it sits over.
library;

import 'package:finance_app/features/activity/view/activity_first_run.dart';
import 'package:finance_app/features/holdings/view/holdings_first_run.dart';
import 'package:finance_app/features/home/view/home_first_run.dart';
import 'package:finance_app/features/shell/view/pinned_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';
import 'header_scroll_harness.dart';

void main() {
  group('a first-run skeleton', () {
    final skeletons = <String, Widget>{
      'Home': const HomeFirstRun(),
      'Holdings': const HoldingsFirstRun(),
      'Activity': const ActivityFirstRun(),
    };

    for (final entry in skeletons.entries) {
      testWidgets('${entry.key} pins its header outside the scrollable', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(phone);
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpApp(entry.value);
        await tester.pump();

        expect(
          find.byType(PinnedHeader),
          findsOneWidget,
          reason: '${entry.key}: the skeleton draws no pinned header at all',
        );
        expect(
          find.descendant(
            of: find.byType(Viewport),
            matching: find.byType(PinnedHeader),
          ),
          findsNothing,
          reason:
              '${entry.key}: the skeleton puts its header inside the '
              'scrolling viewport, so the page it stands in for is the '
              'wrong shape the moment a reader scrolls',
        );
      });
    }
  });
}
