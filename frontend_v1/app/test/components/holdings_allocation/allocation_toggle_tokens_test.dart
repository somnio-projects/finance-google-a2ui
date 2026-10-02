import 'package:finance_app/components/holdings_allocation/allocation_toggle_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// GGU-145 — the toggle's measured palette.
///
/// These assert the *relationships* the Figma artboards carry, not the hex
/// values: a literal repeated here would be a second copy of the same
/// declaration and would pass whatever the widget did with it.
void main() {
  group(AllocationToggleTokens, () {
    testWidgets('answers the palette for the brightness in force', (
      tester,
    ) async {
      late AllocationToggleTokens light;
      late AllocationToggleTokens dark;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: Brightness.light),
          home: Builder(
            builder: (context) {
              light = AllocationToggleTokens.of(context);
              return Theme(
                data: ThemeData(brightness: Brightness.dark),
                child: Builder(
                  builder: (context) {
                    dark = AllocationToggleTokens.of(context);
                    return const SizedBox.shrink();
                  },
                ),
              );
            },
          ),
        ),
      );

      expect(light, same(AllocationToggleTokens.light));
      expect(dark, same(AllocationToggleTokens.dark));
    });

    test(
      'the lit segment is legible without a border on the light artboard',
      () {
        // Light draws no `Bordes` entry, so the fill difference is the only
        // thing that separates the selected segment from the track. Equal
        // fills there would be an invisible toggle, not a subtle one.
        expect(AllocationToggleTokens.light.selectedBorder, isNull);
        expect(
          AllocationToggleTokens.light.selectedSurface,
          isNot(AllocationToggleTokens.light.track),
        );
      },
    );

    test('the dark artboard draws the hairline the light one does not', () {
      // There the selected segment is darker than the track, so the design
      // adds `border/primary` to keep its edge readable. Dropping it is a
      // visible regression the widget test cannot see.
      expect(AllocationToggleTokens.dark.selectedBorder, isNotNull);
    });

    test('a lit label is distinguishable from an unlit one', () {
      for (final tokens in <AllocationToggleTokens>[
        AllocationToggleTokens.light,
        AllocationToggleTokens.dark,
      ]) {
        expect(tokens.selectedText, isNot(tokens.text));
      }
    });

    test('a segment fits the track with its padding on both sides', () {
      // `trackHeight` and `segmentHeight` are measured separately in Figma;
      // this is the arithmetic that has to hold between them, and it is what
      // would break first if one were updated alone.
      expect(
        AllocationToggleTokens.segmentHeight +
            AllocationToggleTokens.trackPadding * 2,
        AllocationToggleTokens.trackHeight,
      );
    });
  });
}
