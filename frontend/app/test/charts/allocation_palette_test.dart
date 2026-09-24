import 'package:finance_app/charts/allocation_palette.dart';
import 'package:finance_app/charts/chart_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(AllocationPalette, () {
    const light = ChartTokens.allocationLight;
    const dark = ChartTokens.allocationDark;

    test("carries the design's measured ramp, in order", () {
      // A literal, on purpose — the counterpart of the catalog contract's
      // component-name assertion. Every other check here compares the palette
      // with itself; this is the client's own declaration of what was read off
      // the rendered page, so a careless edit to `ChartTokens` is caught by
      // something other than a golden.
      expect(
        light.swatches,
        equals(const <Color>[
          Color(0xFF4F5DFF),
          Color(0xFF0C9D8F),
          Color(0xFFD99000),
          Color(0xFF9A5CFF),
          Color(0xFFE0607A),
          Color(0xFF7A8090),
        ]),
      );
      expect(
        dark.swatches,
        equals(const <Color>[
          Color(0xFF7A83FF),
          Color(0xFF2DD4BF),
          Color(0xFFF5B942),
          Color(0xFFC08CFF),
          Color(0xFFFF8FA3),
          Color(0xFFA4A6B0),
        ]),
      );
      // The design does not lighten the weight column for dark mode.
      expect(light.legendWeight, equals(dark.legendWeight));
      expect(light.legendValue, isNot(equals(dark.legendValue)));
    });

    test('wraps the ramp rather than running out', () {
      for (var index = 0; index < 20; index++) {
        expect(
          light.swatchFor(index),
          equals(light.swatches[index % light.swatches.length]),
        );
      }
    });

    test('is a value: equal contents compare equal', () {
      expect(light, equals(light.copyWith()));
      expect(light.hashCode, equals(light.copyWith().hashCode));
      expect(light, isNot(equals(dark)));
      expect(light, equals(light));
    });

    test('copyWith replaces only what it is given', () {
      final recoloured = light.copyWith(legendValue: const Color(0xFF123456));
      expect(recoloured.legendValue, equals(const Color(0xFF123456)));
      expect(recoloured.swatches, equals(light.swatches));
      final reramped = light.copyWith(
        swatches: const <Color>[Color(0xFF000000)],
        legendWeight: const Color(0xFF111111),
        legendDivider: const Color(0xFF222222),
      );
      expect(reramped.swatches, hasLength(1));
      expect(reramped.legendWeight, equals(const Color(0xFF111111)));
      expect(reramped.legendDivider, equals(const Color(0xFF222222)));
    });

    test('lerps pairwise between two ramps of the same length', () {
      final midpoint = light.lerp(dark, 0.5);
      expect(midpoint.swatches, hasLength(light.swatches.length));
      expect(midpoint.swatches.first, isNot(equals(light.swatches.first)));
      expect(light.lerp(dark, 0), equals(light));
      expect(light.lerp(dark, 1), equals(dark));
    });

    test('snaps rather than blending when the ramps differ in length', () {
      // Two ramps of different lengths have no pairwise correspondence, and
      // inventing one would blend the third hue into the fourth.
      final short = light.copyWith(swatches: const <Color>[Color(0xFF000000)]);
      expect(light.lerp(short, 0.2).swatches, equals(light.swatches));
      expect(light.lerp(short, 0.8).swatches, equals(short.swatches));
    });

    test('lerping against nothing keeps the palette', () {
      expect(light.lerp(null, 0.5), same(light));
    });
  });
}
