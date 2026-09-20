/// Framework-free kernel shared by every layer of the finance client.
///
/// Nothing here imports Flutter, `http`, or any other package with an opinion
/// about how the app is delivered, so a type declared here can travel from the
/// transport up to a widget without dragging a framework behind it.
library;

export 'src/app_failure.dart';
export 'src/problem_details.dart';
export 'src/result.dart';
