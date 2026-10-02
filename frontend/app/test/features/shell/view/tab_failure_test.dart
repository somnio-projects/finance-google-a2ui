import 'package:finance_app/features/shell/view/tab_failure.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/pump_app.dart';

void main() {
  group(TabFailure, () {
    testWidgets('prints the backend sentence', (tester) async {
      await tester.pumpApp(const Scaffold(body: TabFailure(message: 'oh no')));

      expect(find.text('oh no'), findsOneWidget);
      // No way out was offered, so none is drawn.
      expect(find.text(TabFailure.retryLabel), findsNothing);
    });

    testWidgets('offers the way out and reports the tap (GGU-110 AC-1)', (
      tester,
    ) async {
      var retries = 0;
      await tester.pumpApp(
        Scaffold(
          body: TabFailure(message: 'oh no', onRetry: () => retries++),
        ),
      );

      expect(find.text('oh no'), findsOneWidget);
      await tester.tap(find.text(TabFailure.retryLabel));
      expect(retries, equals(1));
    });
  });
}
