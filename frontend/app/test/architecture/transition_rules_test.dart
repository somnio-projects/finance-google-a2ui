// The transition-state rules of spec frontend/0020, checked against the
// source.
//
// OD-1 is a sentence a reviewer could forget: *a skeleton for a surface, a
// spinner for an action*. Six pages had drifted the other way before anyone
// named it, which is the signature of a rule nothing enforces. These two
// checks are the enforcement.
//
// Mutation-checked, both ways: putting a `CircularProgressIndicator` back into
// `holdings_view.dart` makes the first test fail and names the file; emptying
// `actionSpinners` makes the second fail on its length.
import 'package:flutter_test/flutter_test.dart';

import 'workspace_sources.dart';

/// The three places a spinner is the *right* affordance: a control the
/// person just operated whose effect is in flight (0020 OD-1).
///
/// Allowed by path, the way `binding_rules_test.dart` allows the geometry
/// seam. Both are attached to a control, neither is a page's whole body.
const Set<String> actionSpinners = <String>{
  // The sign-in button, while the credential is being checked.
  'app/lib/features/sign_in/view/sign_in_email_form.dart',
  // A ticket field being re-rendered by the backend (spec 0006 AC-7).
  'app/lib/components/order_ticket/order_ticket_busy_dot.dart',
  // The same control, one step later: the credential was accepted and the
  // registry has not answered — and on a first sign-in it is enrolling this
  // identity (spec backend/0040). There is no page to skeleton here; the
  // sign-in form has no payload and is still on screen, disabled. A spinner
  // beside the buttons the person just pressed is the affordance 0020 OD-1
  // describes, not the page-shaped wait it forbids.
  'app/lib/features/sign_in/view/sign_in_provisioning_note.dart',
};

/// The 0015 primitives, the only files allowed to drive an animation.
const Set<String> motionPrimitives = <String>{
  'app/lib/skeleton/skeleton_shimmer.dart',
  'app/lib/skeleton/skeleton_pulse.dart',
  'app/lib/skeleton/skeleton_caption.dart',
};

void main() {
  group('transition rules (spec frontend/0020)', () {
    late WorkspaceSources sources;

    setUp(() {
      sources = WorkspaceSources.locate();
    });

    test('a surface waits as a skeleton, never as a spinner', () {
      // `SkeletonCaption` draws an 11 px ring the artboards specify, so it is
      // a primitive rather than a page and is not in scope here; the scope is
      // a screen's own body, which is what kept regressing.
      //
      // The hole is deliberate and worth naming: `skeleton/`, `charts/`,
      // `router/` and anything a feature keeps outside its `view/` directory
      // are not checked. Every screen in this app lives in one of the two
      // directories below, so widening the scope today would only add files
      // that cannot regress; the day that convention breaks, widen it.
      final offenders = <String>[];
      sources.under('app/lib').forEach((path, text) {
        if (!path.contains('/view/') && !path.contains('/components/')) return;
        if (actionSpinners.contains(path)) return;
        if (text.contains('CircularProgressIndicator')) offenders.add(path);
      });
      expect(
        offenders,
        isEmpty,
        reason:
            'a page that waits must draw its own shape in shimmer; a spinner '
            'belongs on a control, and its file belongs in actionSpinners',
      );
    });

    test('the three action spinners are the only exemption, and all exist', () {
      // The size of the hole is the thing worth pinning: a fourth entry is a
      // fourth hole, and an entry that outlives its file is one nobody sees.
      //
      // It went from two to three on 2026-09-23, deliberately and with the
      // count edited in the same commit as the entry — which is what this
      // assertion exists to force. The third is the sign-in screen's
      // provisioning note: the same control one step later, with no page to
      // skeleton behind it (spec backend/0040).
      expect(actionSpinners, hasLength(3));
      final paths = sources.under('app/lib').keys;
      for (final spinner in actionSpinners) {
        expect(paths, contains(spinner));
      }
    });

    test('only the 0015 primitives drive an animation', () {
      // 0020 OD-7: reduced motion is inherited by composing the primitives,
      // which each read `MediaQuery.disableAnimations`. A new skeleton with
      // its own controller would be an animation nobody can turn off.
      final offenders = <String>[];
      sources.under('app/lib/skeleton').forEach((path, text) {
        if (motionPrimitives.contains(path)) return;
        if (text.contains('AnimationController')) offenders.add(path);
      });
      expect(offenders, isEmpty);
      expect(motionPrimitives, hasLength(3));
      final paths = sources.under('app/lib/skeleton').keys;
      for (final primitive in motionPrimitives) {
        expect(paths, contains(primitive));
        expect(
          sources.under('app/lib/skeleton')[primitive],
          contains('MediaQuery.disableAnimationsOf'),
        );
      }
    });
  });
}
