import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/core/capture_setup.dart';

import 'support/fakes.dart';

void main() {
  test('a phone without a token gets one', () async {
    final tokens = FakeTokenRepository();
    final bridge = FakeCaptureBridge();
    await ensureCaptureReady(bridge, tokens, () => 'u1');
    expect(tokens.appRotateCalls, 1);
    expect(bridge.saved, hasLength(1));
  });

  test('an app token the server revoked is replaced, a live one is kept', () async {
    final tokens = FakeTokenRepository();
    final bridge = FakeCaptureBridge()
      ..hasToken = true
      ..tokenUser = 'u1';
    await ensureCaptureReady(bridge, tokens, () => 'u1');
    expect(tokens.appRotateCalls, 0);
    tokens.serverHasActive = false; // revoked on the server (password change, 90 days unused)
    await ensureCaptureReady(bridge, tokens, () => 'u1');
    expect(tokens.appRotateCalls, 1);
    expect(bridge.saved, hasLength(1));
  });

  test('offline (the server cannot be asked) keeps the stored app token', () async {
    final tokens = FakeTokenRepository()..failHasActive = true;
    final bridge = FakeCaptureBridge()
      ..hasToken = true
      ..tokenUser = 'u1';
    await ensureCaptureReady(bridge, tokens, () => 'u1');
    expect(tokens.appRotateCalls, 0);
    expect(bridge.clears, 0);
  });
}
