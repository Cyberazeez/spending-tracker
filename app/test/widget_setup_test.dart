import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/core/widget_setup.dart';

import 'support/fakes.dart';

void main() {
  test('overlapping calls rotate the widget token only once', () async {
    final tokens = FakeTokenRepository();
    final bridge = FakeWidgetBridge();
    await Future.wait([
      ensureWidgetReady(bridge, tokens, () => 'u1'),
      ensureWidgetReady(bridge, tokens, () => 'u1'),
    ]);
    expect(tokens.widgetRotateCalls, 1);
    expect(bridge.savedCredentials, hasLength(1));
  });

  test(
    'signing out in the middle of provisioning leaves no token behind',
    () async {
      final tokens = FakeTokenRepository()..widgetGate = Completer<void>();
      final bridge = FakeWidgetBridge();
      final running = ensureWidgetReady(bridge, tokens, () => 'u1');
      await Future<void>.delayed(Duration.zero);
      final released = releaseWidget(bridge, tokens);
      tokens.widgetGate!.complete();
      await Future.wait([running, released]);

      expect(bridge.hasToken, isFalse);
      expect(tokens.revokedKinds, contains('widget'));
    },
  );

  test('a user change during the network call stores nothing', () async {
    final tokens = FakeTokenRepository()..widgetGate = Completer<void>();
    final bridge = FakeWidgetBridge();
    var user = 'u1';
    final running = ensureWidgetReady(bridge, tokens, () => user);
    await Future<void>.delayed(Duration.zero);
    user = 'u2';
    tokens.widgetGate!.complete();
    await running;
    expect(bridge.savedCredentials, isEmpty);
  });

  test('a widget token the server revoked is replaced, a live one is kept', () async {
    final tokens = FakeTokenRepository();
    final bridge = FakeWidgetBridge()
      ..hasToken = true
      ..tokenUser = 'u1';
    await ensureWidgetReady(bridge, tokens, () => 'u1');
    expect(tokens.widgetRotateCalls, 0);
    tokens.serverHasActive = false; // revoked on the server (password change, 90 days unused)
    await ensureWidgetReady(bridge, tokens, () => 'u1');
    expect(tokens.widgetRotateCalls, 1);
    expect(bridge.savedCredentials, hasLength(1));
  });

  test('offline (the server cannot be asked) keeps the stored widget token', () async {
    final tokens = FakeTokenRepository()..failHasActive = true;
    final bridge = FakeWidgetBridge()
      ..hasToken = true
      ..tokenUser = 'u1';
    await ensureWidgetReady(bridge, tokens, () => 'u1');
    expect(tokens.widgetRotateCalls, 0);
    expect(bridge.clears, 0);
  });
}
