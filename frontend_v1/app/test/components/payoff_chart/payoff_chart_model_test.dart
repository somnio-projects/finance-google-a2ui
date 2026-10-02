import 'package:finance_app/components/payoff_chart/payoff_chart_model.dart';
import 'package:finance_charts/finance_charts.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const line = PayoffLine(
    name: 'Profit / loss',
    points: <PayoffPoint>[PayoffPoint(at: 1, value: 2)],
    tickLabels: <String>[r'$1.00'],
  );

  group('PayoffFact', () {
    test('compares by value', () {
      const fact = PayoffFact(label: 'Entry price', text: r'$152.40');
      expect(fact, const PayoffFact(label: 'Entry price', text: r'$152.40'));
      expect(fact, isNot(const PayoffFact(label: 'Entry', text: r'$152.40')));
    });
  });

  group('PayoffLine', () {
    test('compares by value', () {
      expect(
        line,
        const PayoffLine(
          name: 'Profit / loss',
          points: <PayoffPoint>[PayoffPoint(at: 1, value: 2)],
          tickLabels: <String>[r'$1.00'],
        ),
      );
      expect(
        line,
        isNot(
          const PayoffLine(
            name: 'Other',
            points: <PayoffPoint>[PayoffPoint(at: 1, value: 2)],
            tickLabels: <String>[r'$1.00'],
          ),
        ),
      );
    });
  });

  group('PayoffPoint', () {
    test('compares by value and prints its coordinates', () {
      expect(const PayoffPoint(at: 1, value: 2), line.points.single);
      expect(
        const PayoffPoint(at: 1, value: 2),
        isNot(const PayoffPoint(at: 1, value: 3)),
      );
      expect(
        const PayoffPoint(at: 1, value: 2).toString(),
        'PayoffPoint(1.0, 2.0)',
      );
    });
  });

  group('PayoffChartData', () {
    const data = PayoffChartData(
      title: 'Payoff',
      disclosure: 'Illustrative.',
      totals: <PayoffFact>[],
      lines: <PayoffLine>[line],
      annotations: <PayoffFact>[],
    );

    test('exposes one geometry list per series', () {
      expect(data.series, <List<PayoffPoint>>[line.points]);
    });

    test('draws its axis from the first series', () {
      expect(data.tickLabels, <String>[r'$1.00']);
    });

    test('has no tick labels when no series arrived', () {
      const empty = PayoffChartData(
        title: 'Payoff',
        disclosure: 'Illustrative.',
        totals: <PayoffFact>[],
        lines: <PayoffLine>[],
        annotations: <PayoffFact>[],
      );
      expect(empty.tickLabels, isEmpty);
      expect(empty.series, isEmpty);
    });

    test('compares by value', () {
      expect(
        data,
        const PayoffChartData(
          title: 'Payoff',
          disclosure: 'Illustrative.',
          totals: <PayoffFact>[],
          lines: <PayoffLine>[line],
          annotations: <PayoffFact>[],
        ),
      );
      expect(
        data,
        isNot(
          const PayoffChartData(
            title: 'Other',
            disclosure: 'Illustrative.',
            totals: <PayoffFact>[],
            lines: <PayoffLine>[line],
            annotations: <PayoffFact>[],
          ),
        ),
      );
    });
  });
}
