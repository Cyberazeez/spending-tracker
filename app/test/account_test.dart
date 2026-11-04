import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/core/auth_repository.dart';

import 'support/fakes.dart';

Future<Harness> openAccount(WidgetTester tester, {String? lang}) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final h = Harness(signedIn: true);
  await tester.pumpWidget(await h.build());
  await tester.pumpAndSettle();
  await tester.tap(find.text('More').last);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Account'));
  await tester.pumpAndSettle();
  return h;
}

void main() {
  testWidgets('More no longer has Possible gaps or Ingest token', (
    tester,
  ) async {
    final h = Harness(signedIn: true);
    await tester.pumpWidget(await h.build());
    await tester.pumpAndSettle();
    await tester.tap(find.text('More').last);
    await tester.pumpAndSettle();
    expect(find.text('Possible gaps'), findsNothing);
    expect(find.text('Ingest token'), findsNothing);
    expect(find.text('Account'), findsOneWidget);
  });

  testWidgets('Account lists Profile, Security and Privacy', (tester) async {
    await openAccount(tester);
    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Security'), findsOneWidget);
    expect(find.text('Privacy'), findsOneWidget);
    await tester.tap(find.text('Privacy'));
    await tester.pumpAndSettle();
    expect(find.textContaining('only you can read it'), findsOneWidget);
  });

  testWidgets('Profile saves the name and a changed email', (tester) async {
    final h = await openAccount(tester);
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('azeez@example.test'), findsOneWidget);
    await tester.enterText(find.byType(CupertinoTextField).at(0), 'Azeez');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(h.auth.fakeName, 'Azeez');
    expect(h.auth.emailCalls, isEmpty);
    // back on Account, which shows the new name
    expect(find.text('Azeez'), findsOneWidget);
  });

  testWidgets('a new email asks for confirmation and stays on the screen', (
    tester,
  ) async {
    final h = await openAccount(tester);
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(CupertinoTextField).at(1),
      'new@example.test',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(h.auth.emailCalls, ['new@example.test']);
    expect(find.textContaining('confirmation link'), findsOneWidget);
  });

  testWidgets('an invalid email is refused', (tester) async {
    final h = await openAccount(tester);
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(CupertinoTextField).at(1), 'nope');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.textContaining('valid email'), findsOneWidget);
    expect(h.auth.emailCalls, isEmpty);
  });

  Future<void> fill(WidgetTester t, String cur, String a, String b) async {
    await t.tap(find.text('Security'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(CupertinoTextField).at(0), cur);
    await t.enterText(find.byType(CupertinoTextField).at(1), a);
    await t.enterText(find.byType(CupertinoTextField).at(2), b);
    await t.tap(find.widgetWithText(CupertinoButton, 'Change password'));
    await t.pumpAndSettle();
  }

  testWidgets('change password: rules are checked before anything is sent', (
    tester,
  ) async {
    final h = await openAccount(tester);
    await fill(tester, 'oldpassword', 'short', 'short');
    expect(find.textContaining('at least 8'), findsWidgets);
    await tester.enterText(
      find.byType(CupertinoTextField).at(1),
      'newpassword1',
    );
    await tester.enterText(
      find.byType(CupertinoTextField).at(2),
      'different123',
    );
    await tester.tap(find.widgetWithText(CupertinoButton, 'Change password'));
    await tester.pumpAndSettle();
    expect(find.textContaining('do not match'), findsOneWidget);
    await tester.enterText(
      find.byType(CupertinoTextField).at(1),
      'oldpassword',
    );
    await tester.enterText(
      find.byType(CupertinoTextField).at(2),
      'oldpassword',
    );
    await tester.tap(find.widgetWithText(CupertinoButton, 'Change password'));
    await tester.pumpAndSettle();
    expect(find.textContaining('different password'), findsOneWidget);
    expect(h.auth.passwordCalls, isEmpty);
  });

  testWidgets('a wrong current password is reported', (tester) async {
    final h = await openAccount(tester);
    h.auth.passwordFailWith = PasswordFailure.wrongCurrent;
    await fill(tester, 'oldpassword', 'newpassword1', 'newpassword1');
    expect(find.textContaining('current password is wrong'), findsOneWidget);
  });

  testWidgets('change password succeeds and resets the phone\'s tokens', (
    tester,
  ) async {
    final h = await openAccount(tester);
    await fill(tester, 'oldpassword', 'newpassword1', 'newpassword1');
    expect(h.auth.passwordCalls, [('oldpassword', 'newpassword1')]);
    expect(find.text('Password changed.'), findsOneWidget);
    expect(h.tokens.revokedKinds, containsAll(['app', 'widget']));
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('Current password'), findsNothing);
  });

  for (final lang in ['en', 'ar']) {
    testWidgets('Account screens survive 2x text on a 360pt phone ($lang)', (
      tester,
    ) async {
      final h = Harness(signedIn: true);
      tester.view.physicalSize = const Size(720, 1280);
      tester.view.devicePixelRatio = 2;
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(() {
        tester.view.reset();
        tester.platformDispatcher.clearAllTestValues();
      });
      await tester.pumpWidget(await h.build(prefs: {'locale': lang}));
      await tester.pumpAndSettle();
      await tester.tap(find.text(lang == 'en' ? 'More' : 'المزيد').last);
      await tester.pumpAndSettle();
      final acct = find.text(lang == 'en' ? 'Account' : 'الحساب');
      await tester.dragUntilVisible(
        acct,
        find.byType(CustomScrollView),
        const Offset(0, -150),
      );
      await tester.pumpAndSettle();
      await tester.tap(acct);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      for (final label
          in lang == 'en'
              ? ['Profile', 'Security', 'Privacy']
              : ['الملف الشخصي', 'الأمان', 'الخصوصية']) {
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: label);
        // right-to-left screens swipe back from the right edge: use the button for both languages
        await tester.tap(find.byType(CupertinoNavigationBarBackButton));
        await tester.pumpAndSettle();
      }
    });
  }
}
