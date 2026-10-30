import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/router.dart';

void main() {
  group('redirectFor', () {
    test('signed out always goes to login', () {
      for (final loc in ['/', homePath, lockPath, tokenPath]) {
        expect(
          redirectFor(hasSession: false, locked: true, location: loc),
          loginPath,
        );
        expect(
          redirectFor(hasSession: false, locked: false, location: loc),
          loginPath,
        );
      }
      expect(
        redirectFor(hasSession: false, locked: true, location: loginPath),
        isNull,
      );
    });

    test('signed in but locked goes to the lock screen', () {
      for (final loc in ['/', homePath, loginPath, tokenPath]) {
        expect(
          redirectFor(hasSession: true, locked: true, location: loc),
          lockPath,
        );
      }
      expect(
        redirectFor(hasSession: true, locked: true, location: lockPath),
        isNull,
      );
    });

    test('signed in and unlocked stays on app pages and leaves login/lock', () {
      expect(
        redirectFor(hasSession: true, locked: false, location: homePath),
        isNull,
      );
      expect(
        redirectFor(hasSession: true, locked: false, location: tokenPath),
        isNull,
      );
      expect(
        redirectFor(hasSession: true, locked: false, location: loginPath),
        homePath,
      );
      expect(
        redirectFor(hasSession: true, locked: false, location: lockPath),
        homePath,
      );
      expect(
        redirectFor(hasSession: true, locked: false, location: '/'),
        homePath,
      );
    });
  });
}
