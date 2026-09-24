import 'package:finance_app/components/attribution_waterfall/attribution_waterfall_model.dart';
import 'package:finance_charts/finance_charts.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const step = AttributionStep(
    step: WaterfallStep(key: 'BTC', kind: WaterfallStepKind.gain, level: 67155),
    label: 'Bitcoin',
    valueDisplay: r'$10,230.00',
    cumulativeDisplay: r'$67,155.00',
    detail: r'+18.00% · 1.5 sh · $44,770.00',
    selectedLabel: 'BTC selected',
  );
  const net = AttributionNet(
    label: 'Net',
    amountDisplay: r'+$8,113.60',
    percentDisplay: '+13.74%',
    direction: NetDirection.up,
  );

  group(AttributionStep, () {
    test('exposes the key a drill-down action takes', () {
      expect(step.key, 'BTC');
    });

    test('carries the written detail and the selected caption', () {
      expect(step.detail, r'+18.00% · 1.5 sh · $44,770.00');
      expect(step.selectedLabel, 'BTC selected');
    });

    test('differs when a display string differs', () {
      // The figures are part of what the step *is*: two steps at the same
      // level showing different text are not the same step.
      expect(
        step,
        isNot(
          equals(
            const AttributionStep(
              step: WaterfallStep(
                key: 'BTC',
                kind: WaterfallStepKind.gain,
                level: 67155,
              ),
              label: 'Bitcoin',
              valueDisplay: r'$10,230.01',
              cumulativeDisplay: r'$67,155.00',
              detail: r'+18.00% · 1.5 sh · $44,770.00',
              selectedLabel: 'BTC selected',
            ),
          ),
        ),
      );
    });
  });

  group(AttributionNet, () {
    test('differs when the direction differs', () {
      expect(
        net,
        isNot(
          equals(
            const AttributionNet(
              label: 'Net',
              amountDisplay: r'+$8,113.60',
              percentDisplay: '+13.74%',
              direction: NetDirection.down,
            ),
          ),
        ),
      );
    });
  });

  group(AttributionAnnotation, () {
    test('is equal to an annotation with the same label and text', () {
      expect(
        const AttributionAnnotation(label: 'Net', text: r'$8,113.60'),
        equals(const AttributionAnnotation(label: 'Net', text: r'$8,113.60')),
      );
      expect(
        const AttributionAnnotation(label: 'Net', text: r'$8,113.60'),
        isNot(
          equals(const AttributionAnnotation(label: 'Net', text: r'$8.00')),
        ),
      );
    });
  });

  group(AttributionWaterfallData, () {
    const data = AttributionWaterfallData(
      title: 'Unrealised P/L attribution',
      net: net,
      steps: <AttributionStep>[step],
      annotations: <AttributionAnnotation>[
        AttributionAnnotation(label: 'Net', text: r'$8,113.60'),
      ],
    );

    test('projects the three lists the chart is built from', () {
      expect(data.waterfallSteps, <WaterfallStep>[step.step]);
      expect(data.valueDisplays, <String>[r'$10,230.00']);
      expect(data.axisLabels, <String>['Bitcoin']);
    });

    test('is equal to a model over the same steps, net and notes', () {
      expect(
        data,
        equals(
          const AttributionWaterfallData(
            title: 'Unrealised P/L attribution',
            net: net,
            steps: <AttributionStep>[step],
            annotations: <AttributionAnnotation>[
              AttributionAnnotation(label: 'Net', text: r'$8,113.60'),
            ],
          ),
        ),
      );
    });

    test('differs when an annotation is dropped', () {
      // N-9 as an equality: losing a note is a change, not a detail.
      expect(
        data,
        isNot(
          equals(
            const AttributionWaterfallData(
              title: 'Unrealised P/L attribution',
              net: net,
              steps: <AttributionStep>[step],
              annotations: <AttributionAnnotation>[],
            ),
          ),
        ),
      );
    });
  });
}
