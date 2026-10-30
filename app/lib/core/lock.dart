import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../config.dart';

/// Seam over the platform biometric prompt.
abstract class Authenticator {
  /// True when the user passed Face ID / Touch ID / device passcode.
  Future<bool> authenticate(String reason);
}

class LocalAuthenticator implements Authenticator {
  final _auth = LocalAuthentication();

  @override
  Future<bool> authenticate(String reason) async {
    try {
      // Without any biometrics or passcode set up the device cannot lock the app; let the owner in.
      if (!await _auth.isDeviceSupported()) return true;
      return await _auth.authenticate(localizedReason: reason);
    } on LocalAuthException {
      return false;
    }
  }
}

class LockState {
  const LockState({
    required this.locked,
    this.failed = false,
    this.busy = false,
  });
  final bool locked;
  final bool failed;
  final bool busy;

  LockState copyWith({bool? locked, bool? failed, bool? busy}) => LockState(
    locked: locked ?? this.locked,
    failed: failed ?? this.failed,
    busy: busy ?? this.busy,
  );
}

final authenticatorProvider = Provider<Authenticator>(
  (ref) => LocalAuthenticator(),
);
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final lockProvider = NotifierProvider<LockController, LockState>(
  LockController.new,
);

/// Starts locked. Locks again when the app returns from the background after [AppConfig.lockAfter].
class LockController extends Notifier<LockState> {
  DateTime? _backgroundedAt;

  @override
  LockState build() => const LockState(locked: true);

  Future<bool> unlock(String reason) async {
    if (state.busy) return false;
    state = state.copyWith(busy: true, failed: false);
    final ok = await ref.read(authenticatorProvider).authenticate(reason);
    state = LockState(locked: !ok, failed: !ok);
    return ok;
  }

  /// Used right after a fresh password sign-in, where a second prompt would be redundant.
  void markUnlocked() => state = const LockState(locked: false);

  void lockNow() => state = const LockState(locked: true);

  void onBackground() => _backgroundedAt ??= ref.read(clockProvider)();

  void onForeground() {
    final since = _backgroundedAt;
    _backgroundedAt = null;
    if (since == null) return;
    if (ref.read(clockProvider)().difference(since) >= AppConfig.lockAfter) {
      lockNow();
    }
  }
}
