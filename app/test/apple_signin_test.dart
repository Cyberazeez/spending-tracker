import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:spending_tracker/core/apple_nonce.dart';
import 'package:spending_tracker/core/auth_repository.dart';

import 'support/fakes.dart';

Future<Harness> openLogin(WidgetTester tester, {bool supported = true}) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final h = Harness();
  h.auth.appleSupported = supported;
  await tester.pumpWidget(await h.build());
  await tester.pumpAndSettle();
  return h;
}

void main() {
  group('nonce', () {
    test('is long, random and uses only safe characters', () {
      final a = newAppleNonce();
      final b = newAppleNonce();
      expect(a.length, 32);
      expect(a, isNot(b));
      expect(RegExp(r'^[0-9A-Za-z\-._]+$').hasMatch(a), isTrue);
    });
    test(
      'a seeded generator is repeatable (so the length is the only knob)',
      () {
        expect(newAppleNonce(8, Random(1)), newAppleNonce(8, Random(1)));
      },
    );
    test('sha256Hex matches the known digest', () {
      expect(
        sha256Hex('abc'),
        'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
      );
    });
  });

  testWidgets('the Apple button shows on Sign in and on Create account', (
    tester,
  ) async {
    await openLogin(tester);
    expect(find.byType(SignInWithAppleButton), findsOneWidget);
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();
    expect(find.byType(SignInWithAppleButton), findsOneWidget);
  });

  testWidgets(
    'the Apple button is hidden where Apple sign-in is not available',
    (tester) async {
      await openLogin(tester, supported: false);
      expect(find.byType(SignInWithAppleButton), findsNothing);
      expect(find.text('or'), findsNothing);
    },
  );

  testWidgets('tapping it signs in and goes to the app', (tester) async {
    final h = await openLogin(tester);
    await tester.tap(find.byType(SignInWithAppleButton));
    await tester.pumpAndSettle();
    expect(h.auth.appleCalls, 1);
    expect(find.text('Home'), findsWidgets);
  });

  testWidgets('closing Apple\'s sheet is not an error', (tester) async {
    final h = await openLogin(tester);
    h.auth.appleResult = SocialResult.cancelled;
    await tester.tap(find.byType(SignInWithAppleButton));
    await tester.pumpAndSettle();
    expect(h.auth.appleCalls, 1);
    expect(find.textContaining('Could not sign in'), findsNothing);
    expect(find.text('Home'), findsNothing);
    expect(find.byType(SignInWithAppleButton), findsOneWidget);
  });

  testWidgets('a failure and a lost connection are explained', (tester) async {
    final h = await openLogin(tester);
    h.auth.appleFailWith = SocialFailure.failed;
    await tester.tap(find.byType(SignInWithAppleButton));
    await tester.pumpAndSettle();
    expect(
      find.text('Could not sign in with Apple. Try again.'),
      findsOneWidget,
    );
    h.auth.appleFailWith = SocialFailure.network;
    await tester.tap(find.byType(SignInWithAppleButton));
    await tester.pumpAndSettle();
    expect(find.text('Could not sign in with Apple. Try again.'), findsNothing);
    expect(
      find.text(
        'Could not reach the server. Check your connection and try again.',
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'signing in with Apple after asking to delete shows "welcome back"',
    (tester) async {
      final h = await openLogin(tester);
      h.auth.appleResult = SocialResult.reactivated;
      await tester.tap(find.byType(SignInWithAppleButton));
      await tester.pumpAndSettle();
      expect(find.text('Welcome back'), findsOneWidget);
    },
  );
}
