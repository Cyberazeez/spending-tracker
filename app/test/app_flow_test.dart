import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spending_tracker/core/auth_repository.dart';
import 'package:spending_tracker/core/token_repository.dart';

import 'support/fakes.dart';

void main() {
  testWidgets('signed out shows login and validates required fields', (
    tester,
  ) async {
    final h = Harness();
    await tester.pumpWidget(await h.build());
    await tester.pumpAndSettle();

    expect(find.text('Email'), findsOneWidget);
    await tester.tap(find.widgetWithText(CupertinoButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Required'), findsNWidgets(2));
    expect(h.auth.signInCalls, 0);
  });

  testWidgets('wrong password shows an error and stays on login', (
    tester,
  ) async {
    final h = Harness()..auth.failWith = SignInFailure.invalidCredentials;
    await tester.pumpWidget(await h.build());
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(CupertinoTextField).first,
      'me@example.com',
    );
    await tester.enterText(find.byType(CupertinoTextField).last, 'nope');
    await tester.tap(find.widgetWithText(CupertinoButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Wrong email or password.'), findsOneWidget);
    expect(find.text('Home'), findsNothing);
  });

  testWidgets('network failure shows a different message', (tester) async {
    final h = Harness()..auth.failWith = SignInFailure.network;
    await tester.pumpWidget(await h.build());
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(CupertinoTextField).first,
      'me@example.com',
    );
    await tester.enterText(find.byType(CupertinoTextField).last, 'pw');
    await tester.tap(find.widgetWithText(CupertinoButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Could not reach the server'), findsOneWidget);
  });

  testWidgets('successful sign-in goes straight to the app without Face ID', (
    tester,
  ) async {
    final h = Harness();
    await tester.pumpWidget(await h.build());
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(CupertinoTextField).first,
      'me@example.com',
    );
    await tester.enterText(find.byType(CupertinoTextField).last, 'pw');
    await tester.tap(find.widgetWithText(CupertinoButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(h.auth.signInCalls, 1);
    expect(h.authenticator.calls, 0);
    expect(find.text('Waiting for your first SMS'), findsOneWidget);
    expect(find.text('Transactions'), findsWidgets);
  });

  testWidgets(
    'cold start with a session shows the lock, then the app after Face ID',
    (tester) async {
      final h = Harness(signedIn: true);
      await tester.pumpWidget(await h.build());
      await tester.pumpAndSettle();

      expect(h.authenticator.calls, 1);
      expect(find.text('Waiting for your first SMS'), findsOneWidget);
    },
  );

  testWidgets('failed Face ID keeps the lock screen and allows a retry', (
    tester,
  ) async {
    final h = Harness(signedIn: true)..authenticator.result = false;
    await tester.pumpWidget(await h.build());
    await tester.pumpAndSettle();

    expect(find.text('Locked'), findsOneWidget);
    expect(find.text('Could not unlock. Try again.'), findsOneWidget);

    h.authenticator.result = true;
    await tester.tap(find.widgetWithText(CupertinoButton, 'Unlock'));
    await tester.pumpAndSettle();
    expect(find.text('Waiting for your first SMS'), findsOneWidget);
  });

  testWidgets(
    'language switch flips the app to Arabic right-to-left and is remembered',
    (tester) async {
      final h = Harness(signedIn: true);
      await tester.pumpWidget(await h.build());
      await tester.pumpAndSettle();

      await tester.tap(find.text('More'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Language'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('العربية').last);
      await tester.pumpAndSettle();

      expect(find.text('اللغة'), findsOneWidget);
      final context = tester.element(find.text('اللغة'));
      expect(Directionality.of(context), TextDirection.rtl);
      expect((await SharedPreferences.getInstance()).getString('locale'), 'ar');
    },
  );

  testWidgets('saved Arabic preference is used on start', (tester) async {
    final h = Harness();
    await tester.pumpWidget(await h.build(prefs: {'locale': 'ar'}));
    await tester.pumpAndSettle();
    expect(find.text('البريد الإلكتروني'), findsOneWidget);
  });

  testWidgets(
    'ingest token screen: create shows the token once, rotating asks first',
    (tester) async {
      final h = Harness(signedIn: true);
      await tester.pumpWidget(await h.build());
      await tester.pumpAndSettle();

      await tester.tap(find.text('More'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ingest token'));
      await tester.pumpAndSettle();

      expect(find.text('No active token'), findsOneWidget);
      expect(find.text('X-Ingest-Token'), findsOneWidget);

      await tester.tap(
        find.widgetWithText(CupertinoButton, 'Create new token'),
      );
      await tester.pumpAndSettle();
      expect(h.tokens.rotateCalls, 1);
      expect(find.text('stk_TESTTOKEN'), findsOneWidget);
      expect(find.textContaining('shown only once'), findsOneWidget);

      // Now a token exists, so replacing needs confirmation.
      await tester.tap(find.widgetWithText(CupertinoButton, 'Replace token'));
      await tester.pumpAndSettle();
      expect(find.text('Replace the token?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(h.tokens.rotateCalls, 1);
    },
  );

  testWidgets('token screen shows last used time in Riyadh time', (
    tester,
  ) async {
    final h = Harness(signedIn: true)
      ..tokens.active = IngestTokenInfo(
        label: 'iPhone',
        createdAt: DateTime.utc(2026, 10, 29, 10),
        lastUsedAt: DateTime.utc(2026, 10, 30, 11, 5),
      );
    await tester.pumpWidget(await h.build());
    await tester.pumpAndSettle();
    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ingest token'));
    await tester.pumpAndSettle();

    expect(find.textContaining('30 Oct 14:05'), findsOneWidget);
  });

  testWidgets('sign out returns to login', (tester) async {
    final h = Harness(signedIn: true);
    await tester.pumpWidget(await h.build());
    await tester.pumpAndSettle();

    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(find.text('Email'), findsOneWidget);
  });
}
