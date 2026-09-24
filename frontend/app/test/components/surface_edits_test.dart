import 'package:finance_app/components/surface_edits.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(SurfaceEdits, () {
    void a(String _, String _) {}
    void b(String _, String _) {}

    test('notifies dependents when the callback or the answer changes', () {
      const child = SizedBox.shrink();
      final scope = SurfaceEdits(onOptionChanged: a, child: child);
      expect(
        scope.updateShouldNotify(
          SurfaceEdits(onOptionChanged: a, child: child),
        ),
        isFalse,
      );
      expect(
        scope.updateShouldNotify(
          SurfaceEdits(onOptionChanged: b, child: child),
        ),
        isTrue,
      );
      expect(
        scope.updateShouldNotify(
          SurfaceEdits(onOptionChanged: a, pendingOption: 'size', child: child),
        ),
        isTrue,
      );
      expect(
        scope.updateShouldNotify(
          SurfaceEdits(onOptionChanged: a, rejection: 'no', child: child),
        ),
        isTrue,
      );
    });

    testWidgets('is absent where nothing provides one', (tester) async {
      SurfaceEdits? seen;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            seen = SurfaceEdits.maybeOf(context);
            return const SizedBox.shrink();
          },
        ),
      );
      expect(seen, isNull);
    });
  });
}
