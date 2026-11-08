import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

void main() {
  testWidgets('the widget gets its own token once, tied to the user', (
    tester,
  ) async {
    final h = Harness(signedIn: true)..capture.hasToken = true;
    h.capture.tokenUser = 'user-1';
    await tester.pumpWidget(await h.build());
    await tester.pumpAndSettle();

    expect(h.tokens.widgetRotateCalls, 1);
    expect(h.widget.savedCredentials.single.$2, 'stk_WIDGETTOKEN');
    expect(h.widget.savedCredentials.single.$3, 'user-1');
  });

  testWidgets('no new widget token when the phone already has one', (
    tester,
  ) async {
    final h = Harness(signedIn: true)
      ..capture.hasToken = true
      ..capture.tokenUser = 'user-1'
      ..widget.hasToken = true
      ..widget.tokenUser = 'user-1';
    await tester.pumpWidget(await h.build());
    await tester.pumpAndSettle();

    expect(h.tokens.widgetRotateCalls, 0);
    expect(h.widget.savedCredentials, isEmpty);
  });

  testWidgets('a widget token left by another account is replaced', (
    tester,
  ) async {
    final h = Harness(signedIn: true)
      ..capture.hasToken = true
      ..capture.tokenUser = 'user-1'
      ..widget.hasToken = true
      ..widget.tokenUser = 'someone-else';
    await tester.pumpWidget(await h.build());
    await tester.pumpAndSettle();

    expect(h.widget.clears, 1);
    expect(h.tokens.widgetRotateCalls, 1);
    expect(h.widget.savedCredentials.single.$3, 'user-1');
  });

  testWidgets('sign out revokes the widget token and wipes the shared data', (
    tester,
  ) async {
    final h = Harness(signedIn: true);
    await tester.pumpWidget(await h.build());
    await tester.pumpAndSettle();
    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Sign out'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();

    expect(h.tokens.revokedKinds, containsAll(['app', 'widget']));
    expect(h.widget.hasToken, isFalse);
  });
}
