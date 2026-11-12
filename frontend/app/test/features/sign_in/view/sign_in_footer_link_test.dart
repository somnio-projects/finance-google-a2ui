import 'package:finance_app/features/sign_in/view/sign_in_footer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import '../../../helpers/pump_app.dart';

class _Launcher extends UrlLauncherPlatform with MockPlatformInterfaceMixin {
  final List<String> opened = <String>[];

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> canLaunch(String url) async => true;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    opened.add(url);
    return true;
  }
}

void main() {
  group('the footer links (GGU-156)', () {
    late _Launcher launcher;
    late UrlLauncherPlatform previous;

    setUp(() {
      previous = UrlLauncherPlatform.instance;
      launcher = _Launcher();
      UrlLauncherPlatform.instance = launcher;
    });
    tearDown(() => UrlLauncherPlatform.instance = previous);

    Future<void> pump(WidgetTester tester) =>
        tester.pumpApp(const Scaffold(body: SignInFooter()));

    testWidgets('each is one link, named exactly by its label', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester);
      for (final name in <String>['GitHub', 'Privacy']) {
        final data = tester.getSemantics(find.text(name)).getSemanticsData();
        expect(data.label, name);
        expect(data.flagsCollection.isLink, isTrue);
        expect(data.hasAction(SemanticsAction.tap), isTrue);
      }
      handle.dispose();
    });

    testWidgets('tapping opens the repository and the compliance folder', (
      tester,
    ) async {
      await pump(tester);
      await tester.tap(find.text('GitHub'));
      await tester.pump();
      await tester.tap(find.text('Privacy'));
      await tester.pump();
      expect(launcher.opened, <String>[
        SignInFooter.github.toString(),
        SignInFooter.privacy.toString(),
      ]);
    });

    testWidgets('the keyboard reaches and activates a link', (tester) async {
      await pump(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(launcher.opened, <String>[SignInFooter.github.toString()]);
    });
  });
}
