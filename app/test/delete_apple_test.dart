import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/core/auth_repository.dart';

import 'support/fakes.dart';

Future<Harness> openAppleAccount(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final h = Harness(signedIn: true);
  h.auth.hasPasswordValue = false; // signed up with Apple
  await tester.pumpWidget(await h.build());
  await tester.pumpAndSettle();
  await tester.tap(find.text('More').last);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Account'));
  await tester.pumpAndSettle();
  return h;
}

Future<void> openDelete(WidgetTester tester) async {
  await tester.tap(find.text('Privacy'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Delete my account'));
  await tester.pumpAndSettle();
}

Future<void> confirm(WidgetTester tester, {String word = 'DELETE'}) async {
  await tester.enterText(find.byType(CupertinoTextField).at(0), word);
  await tester.tap(find.widgetWithText(CupertinoButton, 'Delete my account'));
  await tester.pumpAndSettle();
  final sure = find.text('Delete everything');
  if (sure.evaluate().isNotEmpty) {
    await tester.tap(sure);
    await tester.pumpAndSettle();
  }
}

void main() {
  testWidgets(
    'an Apple account has no password field and deletes with Apple\'s proof',
    (tester) async {
      final h = await openAppleAccount(tester);
      await openDelete(tester);
      expect(
        find.byType(CupertinoTextField),
        findsOneWidget,
      ); // only the DELETE word
      expect(find.textContaining('no password'), findsOneWidget);
      await confirm(tester);
      expect(h.auth.deleteAppleCalls.length, 1);
      expect(h.auth.deleteAppleCalls.single.authorizationCode, 'code-1');
      expect(h.auth.deleteCalls, isEmpty);
      expect(find.text('Sign in'), findsWidgets); // back on the login screen
    },
  );

  testWidgets(
    'closing Apple\'s sheet deletes nothing and leaves the screen usable',
    (tester) async {
      final h = await openAppleAccount(tester);
      h.auth.appleProof = null;
      await openDelete(tester);
      await confirm(tester);
      expect(h.auth.deleteAppleCalls, isEmpty);
      expect(find.text('Delete account'), findsWidgets);
      expect(find.textContaining('Could not'), findsNothing);
    },
  );

  testWidgets('the wrong Apple ID is explained and nothing is deleted', (
    tester,
  ) async {
    final h = await openAppleAccount(tester);
    h.auth.deleteFailWith = DeleteFailure.wrongApple;
    await openDelete(tester);
    await confirm(tester);
    expect(
      find.text('That Apple ID is not the one for this account.'),
      findsOneWidget,
    );
    expect(h.auth.deleteAppleCalls, isEmpty);
  });

  testWidgets(
    'Security says there is no password to change for an Apple account',
    (tester) async {
      await openAppleAccount(tester);
      await tester.tap(find.text('Security'));
      await tester.pumpAndSettle();
      expect(find.textContaining('no password to change'), findsOneWidget);
      expect(find.byType(CupertinoTextField), findsNothing);
    },
  );
}
