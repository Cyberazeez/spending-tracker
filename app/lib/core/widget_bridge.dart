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
}

class NoopWidgetBridge implements WidgetBridge {
  @override
  Future<void> save(WidgetSnapshot snapshot, DateTime now) async {}
}

final widgetBridgeProvider = Provider<WidgetBridge>(
  (ref) => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS
      ? MethodChannelWidgetBridge()
      : NoopWidgetBridge(),
);
