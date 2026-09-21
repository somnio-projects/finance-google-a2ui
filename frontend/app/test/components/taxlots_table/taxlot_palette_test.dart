import 'package:finance_app/components/taxlots_table/taxlot_palette.dart';
import 'package:finance_app/components/taxlots_table/taxlot_term_colors.dart';
import 'package:finance_app/components/taxlots_table/taxlot_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

/// How a widget reaches the measured palette, and what makes two terms the
/// same term.
///
/// `TaxLotPalette` is a plain class rather than a `ThemeExtension`: a
/// component that had to be registered on `AppTheme` would mean editing a
/// shared file to add one, which ADR-L D-3 forbids. `of` reads the
/// brightness the theme already carries instead.
void main() {
  group(TaxLotTermColors, () {
    test('two terms with the same four colours are equal', () {
      const one = TaxLotTermColors(
        accent: Color(0xFF0F9D8F),
        chipForeground: Color(0xFF0C6A60),
        chipBackground: Color(0xFFDCEFEC),
        chipBorder: Color(0xFFB8DDD6),
      );
      expect(one, TaxLotTokens.light.longTerm);
      expect(one.hashCode, TaxLotTokens.light.longTerm.hashCode);
      expect(one, isNot(TaxLotTokens.light.shortTerm));
      expect(one, isNot(TaxLotTokens.dark.longTerm));
    });

    test('a term is equal to itself and to nothing of another type', () {
      // The two short-circuits in `==`: the identity fast path, and the
      // type guard. Neither is reached by comparing two distinct terms,
      // so without this the operator is only two-thirds executed.
      final one = TaxLotTokens.light.longTerm;
      expect(one, same(one));
      expect(one == one, isTrue);
      expect(one == Object(), isFalse);
    });

    test('a term differing only in its hairline is a different term', () {
      // The last operand of the `&&` chain. A difference in `accent` alone
      // short-circuits before the other three are ever compared.
      const other = TaxLotTermColors(
        accent: Color(0xFF0F9D8F),
        chipForeground: Color(0xFF0C6A60),
        chipBackground: Color(0xFFDCEFEC),
        chipBorder: Color(0xFF000000),
      );
      expect(other, isNot(TaxLotTokens.light.longTerm));
    });
  });

  group(TaxLotPalette, () {
    Future<TaxLotPalette> read(WidgetTester tester, Brightness brightness) {
      late TaxLotPalette seen;
      return tester
          .pumpApp(
            Builder(
              builder: (context) {
                seen = TaxLotPalette.of(context);
                return const SizedBox.shrink();
              },
            ),
            brightness: brightness,
          )
          .then((_) => seen);
    }

    testWidgets('of reads the light artboard from a light theme', (
      tester,
    ) async {
      expect(await read(tester, Brightness.light), same(TaxLotTokens.light));
    });

    testWidgets('of reads the dark artboard from a dark theme', (tester) async {
      expect(await read(tester, Brightness.dark), same(TaxLotTokens.dark));
    });
  });
}
