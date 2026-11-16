import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/core/auth_repository.dart';
import 'package:spending_tracker/features/auth/google_button.dart';

import 'delete_apple_test.dart' show confirm, openDelete;
import 'support/fakes.dart';

Future<Harness> openLogin(WidgetTester tester, {bool google = true}) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final h = Harness();
  h.auth.googleSupported = google;
  await tester.pumpWidget(await h.build());
  await tester.pumpAndSettle();
  return h;
}

Future<Harness> openGoogleAccount(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final h = Harness(signedIn: true);
  h.auth.hasPasswordValue = false; // signed up with Google
  h.auth.proofProviderValue = SocialProvider.google;
  await tester.pumpWidget(await h.build());
  await tester.pumpAndSettle();
  await tester.tap(find.text('More').last);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Your account'));
  await tester.pumpAndSettle();
  return h;
}

final _google = find.byType(GoogleSignInButton);

void main() {
  testWidgets('the Google button shows on Sign in and on Create account', (
    tester,
  ) async {
    await openLogin(tester);
    expect(_google, findsOneWidget);
    expect(find.text('Sign in with Google'), findsOneWidget);
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();
    expect(_google, findsOneWidget);
  });

  testWidgets('the Google button is hidden where it is not available', (
    tester,
  ) async {
    await openLogin(tester, google: false);
    expect(_google, findsNothing);
  });

  testWidgets('tapping it signs in and goes to the app', (tester) async {
    final h = await openLogin(tester);
    await tester.tap(_google);
    await tester.pumpAndSettle();
    expect(h.auth.googleCalls, 1);
    expect(h.auth.appleCalls, 0);
    expect(find.text('Home'), findsWidgets);
  });

  testWidgets('on Create account it waits for the terms box', (tester) async {
    final h = await openLogin(tester);
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();
    await tester.tap(_google);
    await tester.pumpAndSettle();
    expect(h.auth.googleCalls, 0);
    await tester.tap(find.byType(CupertinoCheckbox));
    await tester.pumpAndSettle();
    await tester.tap(_google);
    await tester.pumpAndSettle();
    expect(h.auth.googleCalls, 1);
  });

  testWidgets('closing Google\'s sheet is not an error', (tester) async {
    final h = await openLogin(tester);
    h.auth.googleResult = SocialResult.cancelled;
    await tester.tap(_google);
    await tester.pumpAndSettle();
    expect(h.auth.googleCalls, 1);
    expect(find.textContaining('Could not sign in'), findsNothing);
    expect(find.text('Home'), findsNothing);
    expect(_google, findsOneWidget);
  });

  testWidgets('a failure and a lost connection are explained', (tester) async {
    final h = await openLogin(tester);
    h.auth.googleFailWith = SocialFailure.failed;
    await tester.tap(_google);
    await tester.pumpAndSettle();
    expect(
      find.text('Could not sign in with Google. Try again.'),
      findsOneWidget,
    );
    h.auth.googleFailWith = SocialFailure.network;
    await tester.tap(_google);
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Could not reach the server. Check your connection and try again.',
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'signing in with Google after asking to delete shows "welcome back"',
    (tester) async {
      final h = await openLogin(tester);
      h.auth.googleResult = SocialResult.reactivated;
      await tester.tap(_google);
      await tester.pumpAndSettle();
      expect(find.text('Welcome back'), findsOneWidget);
    },
  );

  testWidgets(
    'a Google account has no password field and deletes with Google\'s proof',
    (tester) async {
      final h = await openGoogleAccount(tester);
      await openDelete(tester);
      expect(find.byType(CupertinoTextField), findsOneWidget);
      expect(find.textContaining('signed in with Google'), findsOneWidget);
      await confirm(tester);
      expect(h.auth.deleteGoogleCalls, ['google-token']);
      expect(h.auth.deleteAppleCalls, isEmpty);
      expect(h.auth.deleteCalls, isEmpty);
      expect(find.text('Sign in'), findsWidgets);
    },
  );

  testWidgets('closing Google\'s sheet deletes nothing', (tester) async {
    final h = await openGoogleAccount(tester);
    h.auth.googleProof = null;
    await openDelete(tester);
    await confirm(tester);
    expect(h.auth.deleteGoogleCalls, isEmpty);
    expect(find.text('Delete account'), findsWidgets);
    expect(find.textContaining('Could not'), findsNothing);
  });

  testWidgets('the wrong Google account is explained and nothing is deleted', (
    tester,
  ) async {
    final h = await openGoogleAccount(tester);
    h.auth.deleteFailWith = DeleteFailure.wrongGoogle;
    await openDelete(tester);
    await confirm(tester);
    expect(
      find.text('That Google account is not the one for this account.'),
      findsOneWidget,
    );
    expect(h.auth.deleteGoogleCalls, isEmpty);
  });

  testWidgets('the Security page says a Google account has no password', (
    tester,
  ) async {
    await openGoogleAccount(tester);
    await tester.tap(find.text('Security'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Apple or Google'), findsOneWidget);
  });
}
