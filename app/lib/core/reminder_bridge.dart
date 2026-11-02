import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One local notification to schedule: [id] is the obligation instance id, [at] the moment it fires.
class ReminderItem {
  const ReminderItem({
    required this.id,
    required this.title,
    required this.body,
    required this.at,
  });

  final String id;
  final String title;
  final String body;
  final DateTime at;

  @override
  bool operator ==(Object other) =>
      other is ReminderItem &&
      other.id == id &&
      other.title == title &&
      other.body == body &&
      other.at == at;

  @override
  int get hashCode => Object.hash(id, title, body, at);
}

/// Schedules bill reminders as local notifications on the phone (see AppDelegate.swift, "spending_tracker/reminders").
abstract class ReminderBridge {
  /// Asks iOS for permission to notify; false when the owner (or an earlier answer) said no.
  Future<bool> requestPermission();

  /// Replaces every reminder we scheduled before with exactly [items].
  Future<void> replace(List<ReminderItem> items);

  Future<void> clear();
}

class MethodChannelReminderBridge implements ReminderBridge {
  static const _channel = MethodChannel('spending_tracker/reminders');

  @override
  Future<bool> requestPermission() async {
    try {
      return await _channel.invokeMethod<bool>('requestPermission') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<void> replace(List<ReminderItem> items) async {
    try {
      await _channel.invokeMethod<void>('replace', {
        'items': [
          for (final i in items)
            {
              'id': i.id,
              'title': i.title,
              'body': i.body,
              'at': i.at.toUtc().millisecondsSinceEpoch ~/ 1000,
            },
        ],
      });
    } on MissingPluginException {
      // Not iOS (tests, other platforms).
    } on PlatformException {
      // Reminders are a convenience; never break the app over them.
    }
  }

  @override
  Future<void> clear() async {
    try {
      await _channel.invokeMethod<void>('clear');
    } on MissingPluginException {
      // Not iOS.
    } on PlatformException {
      // ignore
    }
  }
}

class NoopReminderBridge implements ReminderBridge {
  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<void> replace(List<ReminderItem> items) async {}

  @override
  Future<void> clear() async {}
}

final reminderBridgeProvider = Provider<ReminderBridge>(
  (ref) => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS
      ? MethodChannelReminderBridge()
      : NoopReminderBridge(),
);
