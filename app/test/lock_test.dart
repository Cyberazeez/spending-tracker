import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/core/lock.dart';

import 'support/fakes.dart';

void main() {
  late FakeAuthenticator authenticator;
  late DateTime now;
  late ProviderContainer container;

  setUp(() {
    authenticator = FakeAuthenticator();
    now = DateTime.utc(2026, 10, 30, 12);
    container = ProviderContainer(
      overrides: [
        authenticatorProvider.overrideWithValue(authenticator),
        clockProvider.overrideWithValue(() => now),
      ],
    );
    addTearDown(container.dispose);
  });

  LockController lock() => container.read(lockProvider.notifier);
  LockState state() => container.read(lockProvider);

  test('starts locked', () {
    expect(state().locked, isTrue);
  });

  test('successful unlock opens the app', () async {
    expect(await lock().unlock('reason'), isTrue);
    expect(state().locked, isFalse);
    expect(state().failed, isFalse);
  });

  test('failed unlock stays locked and reports the failure', () async {
    authenticator.result = false;
    expect(await lock().unlock('reason'), isFalse);
    expect(state().locked, isTrue);
    expect(state().failed, isTrue);
  });

  test('a short trip to the background does not lock', () async {
    await lock().unlock('r');
    lock().onBackground();
    now = now.add(const Duration(seconds: 29));
    lock().onForeground();
    expect(state().locked, isFalse);
  });

  test('30 seconds or more in the background locks', () async {
    await lock().unlock('r');
    lock().onBackground();
    now = now.add(const Duration(seconds: 30));
    lock().onForeground();
    expect(state().locked, isTrue);
  });

  test('foreground without a prior background does nothing', () async {
    await lock().unlock('r');
    lock().onForeground();
    expect(state().locked, isFalse);
  });

  test('markUnlocked skips the prompt after a password sign-in', () {
    lock().markUnlocked();
    expect(state().locked, isFalse);
    expect(authenticator.calls, 0);
  });
}
