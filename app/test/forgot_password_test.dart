import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/core/auth_repository.dart';
import 'package:spending_tracker/router.dart';

import 'support/fakes.dart';

Future<Harness> openForgot(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final h = Harness();
  await tester.pumpWidget(await h.build());
  await tester.pumpAndSettle();
  await tester.tap(find.text('Forgot password?'));
  await tester.pumpAndSettle();
  return h;
}

Future<void> send(WidgetTester t, String email) async {
  await t.enterText(find.byType(CupertinoTextField).first, email);
  await t.tap(find.widgetWithText(CupertinoButton, 'Send reset link'));
  await t.pumpAndSettle();
}

void main() {
  group('redirectFor', () {
    test('signed-out users may open the forgot screen', () {
      expect(
        redirectFor(hasSession: false, locked: false, location: forgotPath),
        isNull,
      );
    });
    test('a recovery session only sees the new-password screen', () {
      expect(
        redirectFor(
          hasSession: true,
          locked: false,
          location: homePath,
          recovery: true,
        ),
        resetPath,
      );
      expect(
        redirectFor(
          hasSession: true,
          locked: true,
          location: resetPath,
          recovery: true,
        ),
        isNull,
      );
    });
    test('the reset screen is not reachable without a recovery', () {
      expect(
        redirectFor(hasSession: true, locked: false, location: resetPath),
        homePath,
      );
    });
  });

  testWidgets(
    'sending the link calls the repository and shows the neutral message',
    (tester) async {
      final h = await openForgot(tester);
      await send(tester, ' sara@example.test ');
      expect(h.auth.resetCalls, ['sara@example.test']);
      expect(find.byKey(const ValueKey('forgot-sent')), findsOneWidget);
      expect(find.textContaining('Send again in'), findsOneWidget);
      await tester.pumpAndSettle(const Duration(seconds: 61));
    },
  );

  testWidgets('an invalid email is rejected before anything is sent', (
    tester,
  ) async {
    final h = await openForgot(tester);
    await send(tester, 'nope');
    expect(h.auth.resetCalls, isEmpty);
    expect(find.byKey(const ValueKey('forgot-sent')), findsNothing);
  });

  testWidgets('rate limiting shows a try-later message', (tester) async {
    final h = await openForgot(tester);
    h.auth.resetFailWith = ResetFailure.tryLater;
    await send(tester, 'sara@example.test');
    expect(find.textContaining('Too many requests'), findsOneWidget);
    expect(find.byKey(const ValueKey('forgot-sent')), findsNothing);
  });

  testWidgets('opening the reset link lands on the new-password screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final h = Harness();
    await tester.pumpWidget(await h.build());
    await tester.pumpAndSettle();
    h.auth.signedInNow();
    h.auth.emitRecovery();
    await tester.pumpAndSettle();
    expect(find.text('Choose a new password'), findsWidgets);

    await tester.enterText(find.byType(CupertinoTextField).at(0), 'short');
    await tester.enterText(find.byType(CupertinoTextField).at(1), 'short');
    await tester.tap(find.widgetWithText(CupertinoButton, 'Save password'));
    await tester.pumpAndSettle();
    expect(h.auth.newPasswordCalls, isEmpty);

    await tester.enterText(find.byType(CupertinoTextField).at(0), 'newpass123');
    await tester.enterText(find.byType(CupertinoTextField).at(1), 'newpass123');
    await tester.tap(find.widgetWithText(CupertinoButton, 'Save password'));
    await tester.pumpAndSettle();
    expect(h.auth.newPasswordCalls, ['newpass123']);
    expect(find.text('Home'), findsWidgets);
  });
}
