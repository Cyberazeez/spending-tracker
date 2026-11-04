import '../config.dart';
import 'token_repository.dart';
import 'widget_bridge.dart';

Future<void>? _running;

/// Gives the widget extension its own read-only token (kind `widget`) for [currentUser], so it can refresh by itself.
/// Only one run at a time (overlapping rotations would revoke each other); rotates only when the phone has none or the
/// stored one belongs to someone else. [currentUser] is read again after the network call so a sign-out in between
/// never leaves a token behind.
Future<void> ensureWidgetReady(
  WidgetBridge bridge,
  TokenRepository tokens,
  String? Function() currentUser,
) {
  return _running ??= _ensure(bridge, tokens, currentUser).whenComplete(() {
    _running = null;
  });
}

Future<void> _ensure(
  WidgetBridge bridge,
  TokenRepository tokens,
  String? Function() currentUser,
) async {
  final userId = currentUser();
  if (userId == null) return;
  try {
    var status = await bridge.credentialStatus();
    if (status.hasToken && status.userId != userId) {
      await bridge.clearCredentials();
      status = await bridge.credentialStatus();
    }
    if (!status.hasToken) {
      final token = await tokens.rotate(label: 'Widget', kind: 'widget');
      if (currentUser() != userId) return; // signed out meanwhile
      await bridge.saveCredentials(AppConfig.supabaseUrl, token, userId);
    }
  } catch (_) {
    // Offline or signed out: retried on the next resume.
  }
}

/// After a password change: a fresh widget token replaces the old one (kept as is when the phone is offline).
Future<void> renewWidgetToken(
  WidgetBridge bridge,
  TokenRepository tokens,
  String? Function() currentUser,
) async {
  try {
    await _running;
  } catch (_) {}
  final run = _renew(bridge, tokens, currentUser).whenComplete(() {
    _running = null;
  });
  _running = run;
  return run;
}

Future<void> _renew(
  WidgetBridge bridge,
  TokenRepository tokens,
  String? Function() currentUser,
) async {
  final userId = currentUser();
  if (userId == null) return;
  try {
    final token = await tokens.rotate(label: 'Widget', kind: 'widget');
    if (currentUser() != userId) return;
    await bridge.saveCredentials(AppConfig.supabaseUrl, token, userId);
  } catch (_) {}
}

/// Sign-out: the widget token stops working on the server and its numbers are wiped from the shared storage.
/// Needs the session, so call it before the actual sign-out.
Future<void> releaseWidget(WidgetBridge bridge, TokenRepository tokens) async {
  // An in-flight provisioning must finish first, or it could store a fresh token after the wipe below.
  try {
    await _running;
  } catch (_) {}
  try {
    await tokens.revoke(kind: 'widget').timeout(const Duration(seconds: 5));
  } catch (_) {
    // Offline: still wiped locally below.
  }
  await bridge.clearCredentials();
}
