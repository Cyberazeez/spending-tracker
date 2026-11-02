import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CaptureStatus {
  const CaptureStatus({required this.hasToken, required this.pending});
  final bool hasToken;

  /// Bank messages the Shortcuts action queued but could not send yet.
  final int pending;
}

/// The native side of the "Add bank message" Shortcuts action (see CaptureStore.swift). It keeps the app's own
/// ingest token in the Keychain and a small offline queue; Dart only provisions and clears the credentials.
abstract class CaptureBridge {
  Future<CaptureStatus> status();
  Future<void> saveCredentials(String url, String token);
  Future<void> clearCredentials();
  Future<void> flush();
}

class MethodChannelCaptureBridge implements CaptureBridge {
  static const _channel = MethodChannel('spending_tracker/capture');

  @override
  Future<CaptureStatus> status() async {
    try {
      final r = await _channel.invokeMapMethod<String, Object?>('status');
      return CaptureStatus(
        hasToken: r?['hasToken'] == true,
        pending: (r?['pending'] as num?)?.toInt() ?? 0,
      );
    } on MissingPluginException {
      return const CaptureStatus(hasToken: true, pending: 0);
    } on PlatformException {
      return const CaptureStatus(hasToken: true, pending: 0);
    }
  }

  @override
  Future<void> saveCredentials(String url, String token) =>
      _call('saveCredentials', {'url': url, 'token': token});

  @override
  Future<void> clearCredentials() => _call('clearCredentials');

  @override
  Future<void> flush() => _call('flush');

  Future<void> _call(String method, [Object? args]) async {
    try {
      await _channel.invokeMethod<void>(method, args);
    } on MissingPluginException {
      // Not on iOS.
    } on PlatformException {
      // Capture is retried on the next resume; never break the app.
    }
  }
}

class NoopCaptureBridge implements CaptureBridge {
  // hasToken true so nothing tries to provision a token that can never be stored.
  @override
  Future<CaptureStatus> status() async =>
      const CaptureStatus(hasToken: true, pending: 0);
  @override
  Future<void> saveCredentials(String url, String token) async {}
  @override
  Future<void> clearCredentials() async {}
  @override
  Future<void> flush() async {}
}

final captureBridgeProvider = Provider<CaptureBridge>(
  (ref) => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS
      ? MethodChannelCaptureBridge()
      : NoopCaptureBridge(),
);
