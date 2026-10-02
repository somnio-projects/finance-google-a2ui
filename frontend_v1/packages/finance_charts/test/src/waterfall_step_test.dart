import 'package:finance_charts/finance_charts.dart';
import 'package:test/test.dart';

void main() {
  const step = WaterfallStep(
    key: 'BTC',
    kind: WaterfallStepKind.gain,
    level: 67155,
  );

  group(WaterfallStep, () {
    test('is equal to another step with the same key, kind and level', () {
      expect(
        step,
        equals(
          const WaterfallStep(
            key: 'BTC',
            kind: WaterfallStepKind.gain,
            level: 67155,
          ),
        ),
      );
    });

    test('differs when the direction the backend sent differs', () {
      // The kind comes from `buckets[].direction`, never from the sign of a
      // figure, so two steps at the same level are still different steps.
      expect(
        step,
        isNot(
          equals(
            const WaterfallStep(
              key: 'BTC',
              kind: WaterfallStepKind.loss,
              level: 67155,
            ),
          ),
        ),
      );
    });

    test('names every kind the contract can produce', () {
      expect(WaterfallStepKind.values, hasLength(4));
    });
  });

  group(WaterfallBar, () {
    const rect = ChartRect(left: 0, top: 10, right: 20, bottom: 30);

    test('is equal to another bar of the same step and rectangle', () {
      expect(
        const WaterfallBar(index: 1, step: step, rect: rect),
        equals(const WaterfallBar(index: 1, step: step, rect: rect)),
      );
    });

    test('differs when it sits in a different band', () {
      expect(
        const WaterfallBar(index: 1, step: step, rect: rect),
        isNot(equals(const WaterfallBar(index: 2, step: step, rect: rect))),
      );
    });
  });

  group(WaterfallConnector, () {
    test('is equal to another connector between the same points', () {
      expect(
        const WaterfallConnector(from: ChartPoint(0, 5), to: ChartPoint(10, 5)),
        equals(
          const WaterfallConnector(
            from: ChartPoint(0, 5),
            to: ChartPoint(10, 5),
          ),
        ),
      );
    });
  });
}
