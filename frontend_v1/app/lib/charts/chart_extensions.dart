import 'package:finance_app/charts/chart_tokens.dart';
import 'package:finance_app/charts/payoff_tokens.dart';
import 'package:flutter/material.dart';

/// Every chart `ThemeExtension` the app carries, for [brightness].
///
/// `AppTheme` spreads this rather than naming each palette, so a chart that
/// needs a palette of its own adds it **here** — beside the colours it is
/// made of — and `app/lib/theme/app_theme.dart` never grows again. GGU-55
/// added `ChartTokens` to that list and GGU-63 added `PayoffTokens`; a third
/// would have made it the `if/elif` chain ADR-L D-3 exists to prevent
/// (`specs/frontend/0005` OD-9).
List<ThemeExtension<Object?>> chartExtensions(Brightness brightness) =>
    <ThemeExtension<Object?>>[
      ChartTokens.forBrightness(brightness),
      // The categorical ramp an allocation donut colours its slices from.
      // Separate from the chart palette because "the third category" is not a
      // semantic role the way gain and loss are (ADR-L D-13).
      ChartTokens.allocationFor(brightness),
      PayoffTokens.forBrightness(brightness),
    ];
