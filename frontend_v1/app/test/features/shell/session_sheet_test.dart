import 'package:finance_app/bootstrap.dart';
import 'package:finance_app/features/home/view/home_page.dart';
import 'package:finance_app/features/shell/view/session_sheet.dart';
import 'package:finance_core/finance_core.dart';
import 'package:finance_views_repository/finance_views_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/auth_fakes.dart';
import '../../helpers/catalog_snapshot.dart';
import '../../helpers/pump_app.dart';

class _MockViewsRepository extends Mock implements ViewsRepository;

void main() {
  testWidgets('the sheet signs out through the callback and closes', (
    tester,
  ) async {
    var signedOut = 0;
    await tester.pumpApp(
      Builder(
        builder: (context) => TextButton(
          onPressed: () =>
              showSessionSheet(context, onSignOut: () => signedOut++),
          child: const Text('open'),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Sign out'), findsOneWidget);
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(signedOut, 1);
    expect(find.text('Sign out'), findsNothing);
  });

  testWidgets('the Home avatar opens the sheet and signs the session out', (
    tester,
  ) async {
    final repository = _MockViewsRepository();
    final snapshot = CatalogSnapshot.load();
    when(
      () => repository.fetchPortfolioViews(
        portfolioId: any(named: 'portfolioId'),
        views: any(named: 'views'),
        options: any(named: 'options'),
      ),
    ).thenAnswer(
      (_) async => Ok<RenderedViews>(
        RenderedViews.fromJson(<String, dynamic>{
          'as_of': '2026-01-15T12:00:00Z',
          'portfolio_id': 'current',
          'views': <String, dynamic>{
            'portfolio.summary.v1': snapshot.exampleFor('PortfolioSummary'),
            'holdings.allocation.v1': snapshot.exampleFor('HoldingsSummary'),
          },
        }),
      ),
    );
    final auth = fakeAuthRepository();
    await auth.signInWithEmail(
      'demo@somnio.dev',
      continueUrl: Uri.parse('http://x'),
    );
    await tester.pumpApp(
      const HomePage(),
      viewsRepository: repository,
      authRepository: auth,
      componentRegistry: buildComponentRegistry(),
      surfaceSize: const Size(390, 1600),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('A'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(auth.state.allowsShell, isFalse);
  });
}
