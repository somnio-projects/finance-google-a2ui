import 'package:finance_app/components/surface_actions.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(SurfaceActions, () {
    void a(SurfaceActionRequest _) {}
    void b(SurfaceActionRequest _) {}

    test('notifies dependents only when the callback changes', () {
      const child = SizedBox.shrink();
      final scope = SurfaceActions(onAction: a, child: child);
      expect(
        scope.updateShouldNotify(SurfaceActions(onAction: a, child: child)),
        isFalse,
      );
      expect(
        scope.updateShouldNotify(SurfaceActions(onAction: b, child: child)),
        isTrue,
      );
    });

    testWidgets('is absent where nothing provides one', (tester) async {
      SurfaceActions? seen;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            seen = SurfaceActions.maybeOf(context);
            return const SizedBox.shrink();
          },
        ),
      );
      expect(seen, isNull);
    });
  });
}
