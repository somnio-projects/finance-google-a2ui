/// The clock an A2UI v1.0 `action` is stamped with.
///
/// `renderer_to_agent.json` **requires** `action.timestamp` (ISO 8601), so a
/// v1.0 renderer cannot send a tap without reading a clock. This class is
/// that read, and the **only** one in `lib/`: the binding rules ban every
/// clock mechanism and allow this file by path, with the allowance's size
/// asserted (`binding_rules_test.dart::nothing reads the device clock`).
///
/// It is not N-13's clock. N-13 forbids reading the device clock for a
/// figure's `as_of`, which travels in the payload; this timestamp is never
/// shown to anyone — it is protocol metadata the agent receives.
class ActionClock {
  /// Creates the clock.
  const ActionClock();

  /// Now, in UTC, as ISO 8601.
  String now() => DateTime.now().toUtc().toIso8601String();
}
