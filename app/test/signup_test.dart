import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/core/auth_repository.dart';

import 'support/fakes.dart';

Future<Harness> openSignUp(WidgetTester tester, {String? lang}) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final h = Harness();
  await tester.pumpWidget(await h.build(prefs: {'locale': ?lang}));
  await tester.pumpAndSettle();
  await tester.tap(find.text(lang == 'ar' ? 'إنشاء حساب' : 'Create account'));
  await tester.pumpAndSettle();
  return h;
}

Future<void> fill(
  WidgetTester t, {
  String name = 'Sara',
  String email = 'sara@example.test',
  String pass = 'password123',
  String again = 'password123',
}) async {
  await t.enterText(find.byType(CupertinoTextField).at(0), name);
  await t.enterText(find.byType(CupertinoTextField).at(1), email);
  await t.enterText(find.byType(CupertinoTextField).at(2), pass);
  await t.enterText(find.byType(CupertinoTextField).at(3), again);
  await t.tap(find.widgetWithText(CupertinoButton, 'Create account').last);
  await t.pumpAndSettle();
}

void main() {
  testWidgets('the login screen links to Create account and swipe goes back', (
    tester,
  ) async {
    await openSignUp(tester);
    expect(find.text('Repeat new password'), findsOneWidget);
    await tester.dragFrom(const Offset(3, 300), const Offset(700, 0));
    await tester.pumpAndSettle();
    expect(find.text('Repeat new password'), findsNothing);
    expect(find.text('Sign in'), findsWidgets);
  });

  testWidgets('a valid sign-up creates the account and goes to the app', (
    tester,
  ) async {
    final h = await openSignUp(tester);
    await fill(tester);
    expect(h.auth.signUpCalls, [('Sara', 'sara@example.test', 'password123')]);
    expect(find.text('Home'), findsWidgets); // signed in, on the tab bar
    expect(h.auth.signInCalls, 0);
  });

  testWidgets('the rules are checked before anything is sent', (tester) async {
    final h = await openSignUp(tester);
    await fill(tester, name: '');
    expect(find.textContaining('Enter your name'), findsOneWidget);
    await fill(tester, email: 'nope');
    expect(find.textContaining('valid email'), findsOneWidget);
    await fill(tester, pass: 'short', again: 'short');
    expect(find.textContaining('at least 8'), findsWidgets);
    await fill(tester, again: 'different123');
    expect(find.textContaining('do not match'), findsOneWidget);
    expect(h.auth.signUpCalls, isEmpty);
  });

  testWidgets('server refusals are explained in plain words', (tester) async {
    final h = await openSignUp(tester);
    h.auth.signUpFailWith = SignUpFailure.emailTaken;
    await fill(tester);
    expect(find.textContaining('already has an account'), findsOneWidget);
    h.auth.signUpFailWith = SignUpFailure.disabled;
    await fill(tester);
    expect(find.textContaining('Sign-up is closed'), findsOneWidget);
    h.auth.signUpFailWith = SignUpFailure.network;
    await fill(tester);
    expect(find.textContaining('Could not reach the server'), findsOneWidget);
    h.auth.signUpFailWith = SignUpFailure.tryLater;
    await fill(tester);
    expect(find.textContaining('Try again in a few minutes'), findsOneWidget);
    h.auth.signUpFailWith = SignUpFailure.weakPassword;
    await fill(tester);
    expect(find.textContaining('too weak'), findsOneWidget);
  });

  testWidgets('when email confirmation is on, the person is told to check it', (
    tester,
  ) async {
    final h = await openSignUp(tester);
    h.auth.signUpResult = SignUpResult.confirmEmail;
    await fill(tester);
    expect(find.textContaining('confirmation link'), findsOneWidget);
    expect(find.text('Home'), findsNothing);
    await tester.tap(find.text('Back to sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Back to sign in'), findsNothing);
    expect(find.text('Sign in'), findsWidgets);
  });

  for (final lang in ['en', 'ar']) {
    testWidgets('sign-up survives 2x text on a 360pt phone ($lang)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(720, 1280);
      tester.view.devicePixelRatio = 2;
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(() {
        tester.view.reset();
        tester.platformDispatcher.clearAllTestValues();
      });
      final h = Harness();
      await tester.pumpWidget(await h.build(prefs: {'locale': lang}));
      await tester.pumpAndSettle();
      final link = find.text(lang == 'ar' ? 'إنشاء حساب' : 'Create account');
      await tester.ensureVisible(link);
      await tester.pumpAndSettle();
      await tester.tap(link);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
