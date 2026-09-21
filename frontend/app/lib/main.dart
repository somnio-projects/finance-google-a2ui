import 'package:finance_app/bootstrap.dart';
import 'package:flutter/widgets.dart';

/// Starts the app.
///
/// Deliberately three lines: everything worth testing lives in `bootstrap.dart`
/// where a test can reach it, and `runApp` itself is Flutter's to get right.
void main() {
  runApp(bootstrap());
}
