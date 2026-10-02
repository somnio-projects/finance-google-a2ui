// The two `Permissions-Policy` headers this client is served under.
//
// The Assistant's composer dictates through the Web Speech API, which needs
// the microphone the policy grants (spec frontend/0023 AC-9). The policy is
// written twice — once in `firebase.json` for Hosting and once in
// `frontend/docker/nginx.conf.template` for the container — because Hosting
// has no nginx, and spec frontend/0017 records what happens when only one of
// the two is edited: the hardening (or here, the grant) is real on a laptop
// and absent where users are.
//
// Neither file is a ship-gate command, so `repo.gate-pairs` cannot compare
// them. This is the comparison, and it runs inside `make test`.
import 'dart:io';

import 'package:test/test.dart';

/// Pulls the `Permissions-Policy` value out of whatever syntax holds it.
///
/// One reader for both files on purpose: the thing being compared is the
/// header's *value*, and two readers would be two chances to normalise it
/// differently. It anchors on the header name and then takes the first
/// quoted string that looks like a directive list — which is `"value": "…"`
/// in JSON and `add_header … "…" always;` in nginx, without this function
/// having to know either. It deliberately does NOT look for `microphone`:
/// a reader that required the thing under test would make the test below
/// unable to fail for the reason it is written for.
String policyIn(String source) {
  final start = source.indexOf('Permissions-Policy');
  if (start < 0) throw StateError('no Permissions-Policy header found');
  final match = RegExp(r'"([^"]*=\([^"]*)"')
      .firstMatch(source.substring(start));
  if (match == null) throw StateError('Permissions-Policy carries no value');
  return match.group(1)!;
}

void main() {
  group('Permissions-Policy (spec frontend/0023 AC-9)', () {
    late String hosting;
    late String container;

    setUp(() {
      // Run from `frontend_v1/`, which is where `dart test test` runs
      // and which carries its own Hosting config (`finance-a2ui-v1`).
      hosting = policyIn(File('firebase.json').readAsStringSync());
      container = policyIn(
        File('docker/nginx.conf.template').readAsStringSync(),
      );
    });

    test('is the same policy in both places', () {
      expect(hosting, container);
    });

    test('grants the microphone to this origin and to nobody else', () {
      for (final policy in <String>[hosting, container]) {
        expect(policy, contains('microphone=(self)'));
        expect(policy, isNot(contains('microphone=(*)')));
      }
    });

    test('leaves every other feature switched off', () {
      // Anti-vacuity: a policy reduced to `microphone=(self)` would satisfy
      // the two tests above and would also have dropped seven denials.
      for (final feature in const <String>[
        'accelerometer',
        'camera',
        'geolocation',
        'gyroscope',
        'magnetometer',
        'payment',
        'usb',
      ]) {
        expect(hosting, contains('$feature=()'));
        expect(container, contains('$feature=()'));
      }
    });

    test('reports a file that has lost the header, rather than passing', () {
      // Anti-vacuity on the reader itself: both halves of this suite are
      // universally quantified over what it returns, so a reader that
      // silently found nothing would satisfy all of them.
      expect(() => policyIn('{}'), throwsStateError);
      expect(
        () => policyIn('Permissions-Policy: see the wiki'),
        throwsStateError,
      );
    });
  });
}
