import 'dart:ui' show Locale;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/obligations/logic.dart';
import '../l10n/app_localizations.dart';
import 'format.dart';
import 'models.dart';
import 'money.dart';
import 'providers.dart';
import 'reminder_bridge.dart';

const _remindersKey = 'reminders_on';

/// Whether bill reminders are switched on (More > Bill reminders). Off until the owner turns it on, because turning it
/// on is what asks iOS for permission to notify.
final remindersEnabledProvider = NotifierProvider<RemindersController, bool>(
  RemindersController.new,
);

class RemindersController extends Notifier<bool> {
  @override
  bool build() => ref.read(sharedPrefsProvider).getBool(_remindersKey) ?? false;

  /// Returns false when iOS refuses (the switch then stays off).
  Future<bool> enable() async {
    final granted = await ref.read(reminderBridgeProvider).requestPermission();
    if (!granted) return false;
    state = true;
    await ref.read(sharedPrefsProvider).setBool(_remindersKey, true);
    return true;
  }

  Future<void> disable() async {
    state = false;
    await ref.read(sharedPrefsProvider).setBool(_remindersKey, false);
    await ref.read(reminderBridgeProvider).clear();
  }
}

/// The notifications to schedule for these instances, worded in [languageCode].
List<ReminderItem> reminderItems(
  List<ObligationInstance> instances,
  DateTime now,
  String languageCode,
) {
  final t = lookupAppLocalizations(Locale(languageCode));
  final arabic = languageCode == 'ar';
  final byId = {for (final i in instances) i.id: i};
  return [
    for (final r in planReminders(instances, now))
      ReminderItem(
        id: r.instanceId,
        title: r.name,
        body: () {
          final amount = byId[r.instanceId]?.expectedHalalas;
          final date = formatDay(r.dueDate);
          return amount == null
              ? t.reminderBody(date)
              : t.reminderBodyAmount(date, formatSar(amount, arabic: arabic));
        }(),
        at: r.fireAt,
      ),
  ];
}
