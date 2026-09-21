import 'package:finance_app/features/activity/view/activity_page.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

void main() {
  group(ActivityPage, () {
    testWidgets('frames the tab with the design title, filters and note', (
      tester,
    ) async {
      await tester.pumpApp(const ActivityPage());
      expect(find.text('Activity'), findsOneWidget);
      expect(find.text('✓ All'), findsOneWidget);
      for (final filter in ActivityPage.filters.skip(1)) {
        expect(find.text(filter), findsOneWidget);
      }
      expect(
        find.text('Simulated activity — resets each session.'),
        findsOneWidget,
      );
    });
  });
}
