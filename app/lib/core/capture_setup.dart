import '../config.dart';
import 'capture_bridge.dart';
import 'token_repository.dart';

/// Makes sure the native Shortcuts action has its own token, then sends anything it queued offline.
/// Safe to call often; it only rotates when the device has no token.
Future<void> ensureCaptureReady(
  CaptureBridge bridge,
  TokenRepository tokens,
) async {
  try {
    final status = await bridge.status();
    if (!status.hasToken) {
      final token = await tokens.rotate(label: 'App', kind: 'app');
      await bridge.saveCredentials(AppConfig.supabaseUrl, token);
    }
    await bridge.flush();
  } catch (_) {
    // Offline or signed out: retried on the next resume.
  }
}

/// Sign-out: the app token stops working on the server and is wiped from this phone.
/// Needs the session, so call it before the actual sign-out.
Future<void> releaseCapture(CaptureBridge bridge, TokenRepository tokens) async {
  try {
    await tokens.revoke(kind: 'app');
  } catch (_) {
    // Offline: the token still gets wiped locally below.
  }
  await bridge.clearCredentials();
}
