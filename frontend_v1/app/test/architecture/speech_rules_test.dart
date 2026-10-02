// Where the browser is allowed to appear, checked against the source.
//
// The voice feature's whole claim is that the Web Speech API sits behind one
// interface: the bloc is driven by a fake, the layering test stays true, and
// the one file a VM cannot compile is the one file the coverage gate excuses
// (spec frontend/0023 OD-2, OD-3, AC-10). A claim like that decays the first
// time somebody reaches for `dart:js_interop` in a widget, so it is a test.
//
// Mutation-checked, both ways: adding `import 'dart:js_interop';` to
// `assistant_mic_button.dart` fails the first test and names the file;
// emptying `browserSeam` fails the second on its length.
import 'package:flutter_test/flutter_test.dart';

import 'workspace_sources.dart';

/// The only file in this app that may speak to the browser directly.
///
/// Allowed by path, the way `binding_rules_test.dart` allows the geometry
/// seam and `transition_rules_test.dart` allows the two action spinners. The
/// *size* of the hole is the thing worth pinning: a second entry here is a
/// second file no test can load.
const Set<String> browserSeam = <String>{'app/lib/speech/speech_web.dart'};

/// The file that chooses between the two implementations.
///
/// Importing it is construction, and construction is `bootstrap.dart`'s
/// (ADR-L D-2). The conditional import lives there rather than in a barrel,
/// for the reason spec 0023 OD-2 gives.
const String platformChoice = 'app/lib/bootstrap.dart';

void main() {
  group('the speech seam (spec frontend/0023)', () {
    late WorkspaceSources sources;

    setUp(() {
      sources = WorkspaceSources.locate();
    });

    test('only the seam speaks to the browser', () {
      expect(
        sources.offenders('app/lib', <String>[
          "import 'dart:js_interop",
          "import 'package:web/",
        ], allow: browserSeam),
        isEmpty,
      );
      // And nowhere under packages/ at all: those are pure Dart and a
      // browser import there would also be a Flutter-free lie.
      expect(
        sources.offenders('packages', <String>[
          "import 'dart:js_interop",
          "import 'package:web/",
        ]),
        isEmpty,
      );
    });

    test('the browser seam is one file, and it exists', () {
      expect(browserSeam, hasLength(1));
      // An allowance that outlives the file it excused is a hole nobody can
      // see — and this one is also a coverage exemption, so it would be two.
      expect(sources.under('app/lib').keys, contains(browserSeam.single));
    });

    test('only the composition root picks the implementation', () {
      final offenders = sources.offenders(
        'app/lib',
        <String>['speech/speech_stub.dart', 'speech/speech_web.dart'],
        allow: <String>{platformChoice, ...browserSeam},
      );
      expect(offenders, isEmpty);
      expect(
        sources.under('app/lib')[platformChoice],
        contains('if (dart.library.js_interop)'),
      );
    });

    test('no bloc and no widget knows which engine it has', () {
      // `SpeechRecognizer` is a type features may name; `WebSpeechRecognizer`
      // and `UnsupportedSpeechRecognizer` are implementations they may not,
      // because branching on one is the seam leaking.
      expect(
        sources.offenders('app/lib/features', <String>[
          'WebSpeechRecognizer',
          'UnsupportedSpeechRecognizer',
        ]),
        isEmpty,
      );
    });
  });
}
