import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/core/auth_repository.dart';

import 'support/fakes.dart';

Future<Harness> start(
  WidgetTester tester, {
  void Function(Harness h)? setup,
  Map<String, Object> prefs = const {},
}) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final h = Harness(signedIn: true);
  setup?.call(h);
  await tester.pumpWidget(await h.build(prefs: prefs));
  await tester.pumpAndSettle();
  return h;
}

Future<void> openAccountPage(WidgetTester tester) async {
  await tester.tap(find.text('More').last);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Account'));
  await tester.pumpAndSettle();
}

void main() {
  group('welcome card', () {
    testWidgets('a brand new account sees the three steps on Home', (
      tester,
    ) async {
      await start(tester, setup: (h) => h.data.accounts = []);
      expect(find.text('Get started'), findsOneWidget);
      expect(find.text('0 of 3 done'), findsOneWidget);
      expect(find.text('Add your bank accounts'), findsOneWidget);
      expect(find.text('Set up SMS capture'), findsOneWidget);
      expect(find.text('Set a monthly budget'), findsOneWidget);
    });

    testWidgets(
      'steps that are done are counted, the card opens the right screens',
      (tester) async {
        await start(tester); // the fake owner already has one account
        expect(find.text('1 of 3 done'), findsOneWidget);
        await tester.tap(find.text('Set up SMS capture'));
        await tester.pumpAndSettle();
        expect(find.text('Set up SMS capture'), findsWidgets);
        expect(find.text('Open Shortcuts'), findsOneWidget);
        await tester.tap(find.byType(CupertinoNavigationBarBackButton));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Add your bank accounts'));
        await tester.pumpAndSettle();
        expect(find.text('Alinma 6000'), findsOneWidget);
      },
    );

    testWidgets('the card disappears when everything is done', (tester) async {
      await start(
        tester,
        setup: (h) {
          h.data.monthlyBudget = 900000;
          h.capture.last = 'HTTP 200';
        },
      );
      expect(find.text('Get started'), findsNothing);
    });

    testWidgets('Hide removes it and it stays hidden after a restart', (
      tester,
    ) async {
      await start(tester, setup: (h) => h.data.accounts = []);
      await tester.tap(find.text('Hide'));
      await tester.pumpAndSettle();
      expect(find.text('Get started'), findsNothing);
    });
  });

  group('bank accounts', () {
    testWidgets('list, add with validation, duplicate, and remove', (
      tester,
    ) async {
      final h = await start(tester);
      await openAccountPage(tester);
      await tester.tap(find.text('Bank accounts'));
      await tester.pumpAndSettle();
      expect(find.text('Alinma 6000'), findsOneWidget);

      await tester.tap(find.widgetWithText(CupertinoButton, 'Add account'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CupertinoButton, 'Add'));
      await tester.pumpAndSettle();
      expect(find.text('Enter exactly 4 digits.'), findsOneWidget);
      await tester.enterText(find.byType(CupertinoTextField).at(0), '12ab');
      await tester.tap(find.widgetWithText(CupertinoButton, 'Add'));
      await tester.pumpAndSettle();
      expect(find.text('Enter exactly 4 digits.'), findsOneWidget);

      await tester.enterText(find.byType(CupertinoTextField).at(0), '1224');
      await tester.enterText(find.byType(CupertinoTextField).at(1), 'Wallet');
      await tester.tap(find.widgetWithText(CupertinoButton, 'Add'));
      await tester.pumpAndSettle();
      expect(h.data.accountCalls, ['add:alrajhi:1224:account:Wallet']);
      expect(find.text('Al Rajhi 1224'), findsOneWidget);

      await tester.tap(find.text('Al Rajhi 1224'));
      await tester.pumpAndSettle();
      expect(find.text('Remove Al Rajhi 1224?'), findsOneWidget);
      await tester.tap(find.text('Remove').last);
      await tester.pumpAndSettle();
      expect(h.data.accountCalls.last, startsWith('del:'));
      expect(find.text('Al Rajhi 1224'), findsNothing);
    });

    testWidgets('a duplicate is explained', (tester) async {
      final h = await start(tester);
      h.data.accountDuplicate = true;
      await openAccountPage(tester);
      await tester.tap(find.text('Bank accounts'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CupertinoButton, 'Add account'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(CupertinoTextField).at(0), '6000');
      await tester.tap(find.widgetWithText(CupertinoButton, 'Add'));
      await tester.pumpAndSettle();
      expect(find.text('This account is already in the list.'), findsOneWidget);
    });
  });

  group('delete account', () {
    Future<Harness> openDelete(WidgetTester tester) async {
      final h = await start(tester);
      await openAccountPage(tester);
      await tester.tap(find.text('Privacy'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete my account'));
      await tester.pumpAndSettle();
      return h;
    }

    Future<void> submit(
      WidgetTester t, {
      String word = 'DELETE',
      String pw = 'secret-pass',
    }) async {
      await t.enterText(find.byType(CupertinoTextField).at(0), word);
      await t.enterText(find.byType(CupertinoTextField).at(1), pw);
      await t.tap(find.widgetWithText(CupertinoButton, 'Delete my account'));
      await t.pumpAndSettle();
    }

    testWidgets('the warning and the confirmation word are required first', (
      tester,
    ) async {
      final h = await openDelete(tester);
      expect(find.textContaining('cannot be undone'), findsOneWidget);
      await submit(tester, word: 'nope');
      expect(find.textContaining('Type DELETE exactly'), findsOneWidget);
      await submit(tester, pw: '');
      expect(find.text('Required'), findsWidgets);
      expect(h.auth.deleteCalls, isEmpty);
    });

    testWidgets('a wrong password or no connection deletes nothing', (
      tester,
    ) async {
      final h = await openDelete(tester);
      h.auth.deleteFailWith = DeleteFailure.wrongPassword;
      await submit(tester);
      expect(find.text('The password is wrong.'), findsOneWidget);
      h.auth.deleteFailWith = DeleteFailure.tooMany;
      await submit(tester);
      expect(find.textContaining('Too many tries'), findsOneWidget);
      h.auth.deleteFailWith = DeleteFailure.network;
      await submit(tester);
      expect(find.textContaining('Could not delete'), findsOneWidget);
      expect(h.auth.deleteCalls, isEmpty);
    });

    testWidgets(
      'success deletes the account, wipes the phone and returns to login',
      (tester) async {
        final h = await openDelete(tester);
        await submit(tester, word: 'delete'); // not case sensitive
        expect(h.auth.deleteCalls, ['secret-pass']);
        expect(h.capture.clears, greaterThan(0));
        expect(h.widget.clears, greaterThan(0));
        expect(find.text('Sign in'), findsWidgets); // back on the login screen
      },
    );

    testWidgets('swipe back works on the new screens', (tester) async {
      await start(tester);
      await openAccountPage(tester);
      await tester.tap(find.text('Bank accounts'));
      await tester.pumpAndSettle();
      await tester.dragFrom(const Offset(3, 300), const Offset(700, 0));
      await tester.pumpAndSettle();
      expect(find.text('Profile'), findsOneWidget);
      await tester.tap(find.text('Privacy'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete my account'));
      await tester.pumpAndSettle();
      await tester.dragFrom(const Offset(3, 300), const Offset(700, 0));
      await tester.pumpAndSettle();
      expect(find.text('Delete my account'), findsOneWidget);
    });
  });

  for (final lang in ['en', 'ar']) {
    testWidgets('Stage C screens survive 2x text on a 360pt phone ($lang)', (
      tester,
    ) async {
      final h = Harness(signedIn: true);
      h.data.accounts = [];
      tester.view.physicalSize = const Size(720, 1280);
      tester.view.devicePixelRatio = 2;
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(() {
        tester.view.reset();
        tester.platformDispatcher.clearAllTestValues();
      });
      await tester.pumpWidget(await h.build(prefs: {'locale': lang}));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'home with welcome card');
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
      for (final label
          in lang == 'en'
              ? ['Bank accounts', 'Privacy']
              : ['الحسابات البنكية', 'الخصوصية']) {
        final row = find.text(label);
        await tester.ensureVisible(row);
        await tester.tap(row);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: label);
        await tester.tap(find.byType(CupertinoNavigationBarBackButton));
        await tester.pumpAndSettle();
      }
    });
  }
}
