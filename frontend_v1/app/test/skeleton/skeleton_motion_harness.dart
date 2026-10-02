/// Shared by the three skeleton primitives' suites: how to pump a widget
/// that never settles, and how to pump it under reduced motion.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';

/// Pumps [subject] once — never `pumpAndSettle`, because a repeating
/// animation never settles and that is the point of the widget.
Future<void> pumpMotion(
  WidgetTester tester,
  Widget subject, {
  bool reducedMotion = false,
  Brightness brightness = Brightness.light,
}) => tester.pumpApp(
  MediaQuery(
    data: MediaQueryData(disableAnimations: reducedMotion),
    child: Scaffold(body: Center(child: subject)),
  ),
  brightness: brightness,
);

/// The gradient a decorated container currently paints.
LinearGradient gradientOf(WidgetTester tester, Finder finder) {
  final container = tester.widget<Container>(finder);
  final decoration = container.decoration! as BoxDecoration;
  return decoration.gradient! as LinearGradient;
}
