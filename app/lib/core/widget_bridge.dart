import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What the home-screen widget shows. Amounts are halalas; [budgetHalalas] is null when no monthly budget is set.
class WidgetSnapshot {
  const WidgetSnapshot({
    required this.todayHalalas,
    required this.monthHalalas,
    required this.budgetHalalas,
    required this.language,
  });

  final int todayHalalas;
  final int monthHalalas;
  final int? budgetHalalas;
  final String language; // 'en' | 'ar'

  @override
  bool operator ==(Object other) =>
      other is WidgetSnapshot &&
      other.todayHalalas == todayHalalas &&
      other.monthHalalas == monthHalalas &&
      other.budgetHalalas == budgetHalalas &&
      other.language == language;

  @override
  int get hashCode =>
      Object.hash(todayHalalas, monthHalalas, budgetHalalas, language);
}

/// Hands the numbers to the iOS widget through the shared App Group (see AppDelegate.swift).
abstract class WidgetBridge {
  Future<void> save(WidgetSnapshot snapshot, DateTime now);

  /// The widget's own read-only token (kind `widget`): lets it fetch fresh numbers without opening the app.
  Future<WidgetCredentialStatus> credentialStatus();
  Future<void> saveCredentials(String url, String token, String userId);
  Future<void> clearCredentials();
}

class WidgetCredentialStatus {
  const WidgetCredentialStatus({required this.hasToken, this.userId});
  final bool hasToken;
  final String? userId;
}

class MethodChannelWidgetBridge implements WidgetBridge {
  static const _channel = MethodChannel('spending_tracker/widget');

  @override
  Future<void> save(WidgetSnapshot s, DateTime now) async {
    try {
      await _channel.invokeMethod<void>('save', {
        'today': s.todayHalalas,
        'month': s.monthHalalas,
        'budget': s.budgetHalalas, // null removes the key on the native side
        'lang': s.language,
        // When the numbers were taken, so the widget can tell a stale "today" from a fresh one.
        'updated': now.toUtc().millisecondsSinceEpoch ~/ 1000,
      });
    } on MissingPluginException {
      // Not running on iOS (tests, other platforms): nothing to update.
    } on PlatformException {
      // The widget is a convenience; never let it break the app.
    }
  }

  @override
  Future<WidgetCredentialStatus> credentialStatus() async {
    try {
      final r = await _channel.invokeMapMethod<String, Object?>(
        'credentialsStatus',
      );
      return WidgetCredentialStatus(
        hasToken: r?['hasToken'] == true,
        userId: r?['userId'] as String?,
      );
    } on MissingPluginException {
      return const WidgetCredentialStatus(hasToken: true);
    } on PlatformException {
      return const WidgetCredentialStatus(hasToken: true);
    }
  }

  @override
  Future<void> saveCredentials(String url, String token, String userId) =>
      _call('saveCredentials', {'url': url, 'token': token, 'userId': userId});

  @override
  Future<void> clearCredentials() => _call('clearCredentials');

  Future<void> _call(String method, [Object? args]) async {
    try {
      await _channel.invokeMethod<void>(method, args);
    } on MissingPluginException {
      // Not on iOS.
    } on PlatformException {
      // Retried on the next resume.
    }
  }
}

class NoopWidgetBridge implements WidgetBridge {
  @override
  Future<void> save(WidgetSnapshot snapshot, DateTime now) async {}

  // hasToken true so nothing tries to provision a token that can never be stored.
  @override
  Future<WidgetCredentialStatus> credentialStatus() async =>
      const WidgetCredentialStatus(hasToken: true);
  @override
  Future<void> saveCredentials(String url, String token, String userId) async {}
  @override
  Future<void> clearCredentials() async {}
}

final widgetBridgeProvider = Provider<WidgetBridge>(
  (ref) => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS
      ? MethodChannelWidgetBridge()
      : NoopWidgetBridge(),
);
