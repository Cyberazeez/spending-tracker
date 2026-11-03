import '../config.dart';
import 'capture_bridge.dart';
import 'token_repository.dart';

Future<void>? _running;

/// Makes sure the native Shortcuts action has its own token for [userId], then sends anything it queued offline.
/// Safe to call often: only one run happens at a time (two overlapping rotations would revoke each other), and it
/// only rotates when the phone has no token or the stored one belongs to someone else.
/// [currentUser] is read again after the network call so a sign-out in between never leaves a token behind.
Future<void> ensureCaptureReady(
  CaptureBridge bridge,
  TokenRepository tokens,
  String? Function() currentUser,
) {
  return _running ??= _ensure(bridge, tokens, currentUser).whenComplete(() {
    _running = null;
  });
}

Future<void> _ensure(
  CaptureBridge bridge,
  TokenRepository tokens,
  String? Function() currentUser,
) async {
  final userId = currentUser();
  if (userId == null) return;
  try {
    var status = await bridge.status();
    if (status.hasToken && status.userId != userId) {
      // Left over from another account (or from before accounts were recorded): never upload into it.
      await bridge.clearCredentials();
      status = await bridge.status();
    }
    if (!status.hasToken) {
      final token = await tokens.rotate(label: 'App', kind: 'app');
      if (currentUser() != userId) return; // signed out meanwhile
      await bridge.saveCredentials(AppConfig.supabaseUrl, token, userId);
    }
    await bridge.flush();
  } catch (_) {
    // Offline or signed out: retried on the next resume.
  }
}

/// Sign-out: the app token stops working on the server and is wiped from this phone.
/// Needs the session, so call it before the actual sign-out.
Future<void> releaseCapture(
  CaptureBridge bridge,
  TokenRepository tokens,
) async {
  // An in-flight provisioning must finish first, or it could store a fresh token after the wipe below.
  try {
    await _running;
  } catch (_) {}
  try {
    await tokens.revoke(kind: 'app').timeout(const Duration(seconds: 5));
  } catch (_) {
    // Offline: the token still gets wiped locally below.
  }
  await bridge.clearCredentials();
}
