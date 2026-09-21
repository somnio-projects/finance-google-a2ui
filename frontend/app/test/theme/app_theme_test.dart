import 'package:finance_app/theme/app_spacing.dart';
import 'package:finance_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(AppTheme, () {
    test('light and dark carry the brightness they claim', () {
      expect(AppTheme.light.colorScheme.brightness, equals(Brightness.light));
      expect(AppTheme.dark.colorScheme.brightness, equals(Brightness.dark));
    });

    test('both themes are Material 3', () {
      expect(AppTheme.light.useMaterial3, isTrue);
      expect(AppTheme.dark.useMaterial3, isTrue);
    });

    test('both themes carry the spacing extension', () {
      expect(
        AppTheme.light.extension<AppSpacing>(),
        equals(AppSpacing.standard),
      );
      expect(
        AppTheme.dark.extension<AppSpacing>(),
        equals(AppSpacing.standard),
      );
    });

    test('cards are outlined rather than elevated', () {
      expect(AppTheme.light.cardTheme.elevation, equals(0));
      expect(AppTheme.dark.cardTheme.shape, isA<RoundedRectangleBorder>());
    });
  });

  group(AppSpacing, () {
    test('the standard scale ascends', () {
      const scale = AppSpacing.standard;
      expect(scale.xs, lessThan(scale.sm));
      expect(scale.sm, lessThan(scale.md));
      expect(scale.md, lessThan(scale.lg));
    });

    group('copyWith', () {
      test('returns an equal scale when given nothing', () {
        expect(AppSpacing.standard.copyWith(), equals(AppSpacing.standard));
      });

      test('replaces every supplied value', () {
        final scale = AppSpacing.standard.copyWith(xs: 1, sm: 2, md: 3, lg: 4);
        expect(<double>[
          scale.xs,
          scale.sm,
          scale.md,
          scale.lg,
        ], equals(<double>[1, 2, 3, 4]));
      });
    });

    test('hashes equal scales alike', () {
      expect(<AppSpacing>{
        AppSpacing.standard,
        AppSpacing.standard.copyWith(),
      }, hasLength(1));
      expect(
        AppSpacing.standard.hashCode,
        equals(AppSpacing.standard.copyWith().hashCode),
      );
    });

    group('lerp', () {
      test('returns itself when the other scale is null', () {
        expect(
          AppSpacing.standard.lerp(null, 0.5),
          equals(AppSpacing.standard),
        );
      });

      test('interpolates every value', () {
        const other = AppSpacing(xs: 8, sm: 16, md: 32, lg: 48);
        final halfway = AppSpacing.standard.lerp(other, 0.5);
        expect(halfway.xs, equals(6));
        expect(halfway.md, equals(24));
      });
    });

    group('of', () {
      testWidgets('reads the scale the theme supplied', (tester) async {
        late AppSpacing resolved;
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: Builder(
              builder: (context) {
                resolved = AppSpacing.of(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        );
        expect(resolved, equals(AppSpacing.standard));
      });

      testWidgets('falls back to the standard scale without one', (
        tester,
      ) async {
        late AppSpacing resolved;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                resolved = AppSpacing.of(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        );
        expect(resolved, equals(AppSpacing.standard));
      });
    });
  });
}
