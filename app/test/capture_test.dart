import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

void main() {
  testWidgets('opening the app gives the Shortcuts action its own token once', (
    tester,
  ) async {
    final h = Harness(signedIn: true);
    await tester.pumpWidget(await h.build());
    await tester.pumpAndSettle();

    expect(h.tokens.appRotateCalls, 1);
    expect(h.capture.saved.single.$2, 'stk_APPTOKEN');
    expect(h.capture.saved.single.$1, startsWith('https://'));
    // The shortcut token on the Ingest token screen is untouched.
    expect(h.tokens.rotateCalls, 0);
    expect(h.capture.flushes, greaterThanOrEqualTo(1));
  });

  testWidgets('no new token when the phone already has one', (tester) async {
    final h = Harness(signedIn: true)..capture.hasToken = true;
    await tester.pumpWidget(await h.build());
    await tester.pumpAndSettle();

    expect(h.tokens.appRotateCalls, 0);
    expect(h.capture.saved, isEmpty);
    expect(h.capture.flushes, greaterThanOrEqualTo(1));
  });

  testWidgets('coming back to the app sends the queued messages', (
    tester,
  ) async {
    final h = Harness(signedIn: true)..capture.hasToken = true;
    await tester.pumpWidget(await h.build());
    await tester.pumpAndSettle();
    final before = h.capture.flushes;

    for (final s in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(s);
    }
    await tester.pumpAndSettle();

    expect(h.capture.flushes, before + 1);
  });

  testWidgets('sign out revokes the app token and wipes it from the phone', (
    tester,
  ) async {
    final h = Harness(signedIn: true);
    await tester.pumpWidget(await h.build());
    await tester.pumpAndSettle();
    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();

    expect(h.tokens.appRevokeCalls, 1);
    expect(h.capture.clears, 1);
    expect(h.capture.hasToken, isFalse);
  });
}
