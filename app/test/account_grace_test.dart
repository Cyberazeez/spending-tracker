import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

Future<void> _signIn(WidgetTester tester, Harness h) async {
  await tester.pumpWidget(await h.build());
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byType(CupertinoTextField).first,
    'me@example.com',
  );
  await tester.enterText(find.byType(CupertinoTextField).last, 'pw');
  await tester.tap(find.widgetWithText(CupertinoButton, 'Sign in'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'signing in while a deletion is pending says the account is active again',
    (tester) async {
      final h = Harness();
      h.auth.reactivateOnSignIn = true;
      await _signIn(tester, h);
      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.textContaining('deletion is cancelled'), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text('Welcome back'), findsNothing);
    },
  );

  testWidgets('a normal sign-in shows no notice', (tester) async {
    final h = Harness();
    await _signIn(tester, h);
    expect(find.text('Welcome back'), findsNothing);
  });
}
