import 'package:finance_charts/finance_charts.dart';
import 'package:test/test.dart';

void main() {
  group('powerOfTen', () {
    test('returns the largest power of ten at or below a value ≥ 1', () {
      expect(powerOfTen(1), 1);
      expect(powerOfTen(9.9), 1);
      expect(powerOfTen(10), 10);
      expect(powerOfTen(1002.5), 1000);
    });

    test('walks downwards for a value below 1', () {
      expect(powerOfTen(0.5), closeTo(0.1, 1e-12));
      expect(powerOfTen(0.04), closeTo(0.01, 1e-12));
    });

    test('falls back to 1 for a non-positive value', () {
      // The callers guard against this, but a helper that divides by its own
      // result must not be able to return zero.
      expect(powerOfTen(0), 1);
      expect(powerOfTen(-5), 1);
    });
  });

  group('niceStep', () {
    test('chooses 1, 2, 5 or 10 times a power of ten', () {
      // One case per branch, picked just above each geometric-mean threshold:
      // sqrt(2) ≈ 1.414, sqrt(10) ≈ 3.162, sqrt(50) ≈ 7.071.
      expect(niceStep(10, 10), 1);
      expect(niceStep(20, 10), 2);
      expect(niceStep(40, 10), 5);
      expect(niceStep(80, 10), 10);
    });

    test('returns zero for a span or count that cannot be divided', () {
      expect(niceStep(0, 4), 0);
      expect(niceStep(-10, 4), 0);
      expect(niceStep(10, 0), 0);
    });
  });

  group('niceBounds', () {
    test('rounds a domain outwards to whole steps', () {
      final bounds = niceBounds(min: 3, max: 47, targetCount: 5);
      expect(bounds.step, 10);
      expect(bounds.min, 0);
      expect(bounds.max, 50);
    });

    test('leaves a domain that already lands on whole steps alone', () {
      final bounds = niceBounds(min: 0, max: 50, targetCount: 5);
      expect(bounds.min, 0);
      expect(bounds.max, 50);
    });

    test('widens a degenerate domain by a unit either side', () {
      // Every step at the same level — a walk that went nowhere. Without this
      // the scale would divide by a zero span.
      final bounds = niceBounds(min: 7, max: 7, targetCount: 2);
      expect(bounds.min, 6);
      expect(bounds.max, 8);
      expect(bounds.step, 1);
    });

    test('recovers the reference waterfall axis from the design', () {
      // The catalog page's preview spans 479,675 → 483,685 and is drawn on a
      // 478,000 → 484,000 axis. This is the observation the default interval
      // count was read from; see `specs/frontend/0002`.
      final bounds = niceBounds(min: 479675, max: 483685, targetCount: 2);
      expect(bounds.step, 2000);
      expect(bounds.min, 478000);
      expect(bounds.max, 484000);
    });
  });
}
