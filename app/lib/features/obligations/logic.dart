import '../../core/models.dart';

/// Today's Riyadh calendar date as UTC midnight, from any instant.
DateTime riyadhToday(DateTime now) {
  final r = now.toUtc().add(const Duration(hours: 3));
  return DateTime.utc(r.year, r.month, r.day);
}

/// A pending instance counts as overdue once today is past the due date plus its grace days.
String effectiveStatus(ObligationInstance i, DateTime today) {
  if (i.status != 'pending' && i.status != 'overdue') return i.status;
  final limit = i.dueDate.add(Duration(days: i.graceDays));
  return today.isAfter(limit) ? 'overdue' : 'pending';
}

/// Where an instance appears: upcoming (pending, due within [days]), overdue, or history (paid / skipped).
enum ObSection { upcoming, overdue, history }

List<ObligationInstance> inSection(
  List<ObligationInstance> all,
  ObSection section,
  DateTime today, {
  int days = 30,
}) {
  final horizon = today.add(Duration(days: days));
  final out = all.where((i) {
    final s = effectiveStatus(i, today);
    return switch (section) {
      ObSection.upcoming => s == 'pending' && !i.dueDate.isAfter(horizon),
      ObSection.overdue => s == 'overdue',
      ObSection.history => s == 'paid' || s == 'skipped',
    };
  }).toList();
  out.sort(
    (a, b) => section == ObSection.history
        ? b.dueDate.compareTo(a.dueDate)
        : a.dueDate.compareTo(b.dueDate),
  );
  return out;
}

/// Money still to pay in the upcoming list (unknown amounts count as zero).
int committedHalalas(List<ObligationInstance> upcoming) => upcoming.fold(
  0,
  (sum, i) =>
      sum +
      ((i.expectedHalalas ?? 0) - (i.actualHalalas ?? 0)).clamp(0, 1 << 40),
);

/// Instances due in the Riyadh month of [today] that are not skipped: what is "committed" this month.
List<ObligationInstance> thisMonth(
  List<ObligationInstance> all,
  DateTime today,
) => all
    .where(
      (i) =>
          i.status != 'skipped' &&
          i.dueDate.year == today.year &&
          i.dueDate.month == today.month,
    )
    .toList();

class Reminder {
  const Reminder({
    required this.id,
    required this.instanceId,
    required this.fireAt,
    required this.name,
    required this.dueDate,
  });
  final int id;
  final String instanceId;
  final DateTime fireAt; // UTC instant
  final String name;
  final DateTime dueDate;
}

/// Reminders at 09:00 Riyadh, [ObligationInstance.leadDays] before each unpaid due date. Only the future ones, soonest
/// first, capped (iOS keeps at most 64 pending local notifications). Scheduling them is the iOS build's job.
List<Reminder> planReminders(
  List<ObligationInstance> all,
  DateTime now, {
  int max = 60,
}) {
  final out = <Reminder>[];
  for (final i in all) {
    if (i.status != 'pending' && i.status != 'overdue') continue;
    final fire = i.dueDate
        .subtract(Duration(days: i.leadDays))
        .add(const Duration(hours: 9 - 3));
    if (!fire.isAfter(now.toUtc())) continue;
    out.add(
      Reminder(
        id: i.id.hashCode & 0x7fffffff,
        instanceId: i.id,
        fireAt: fire,
        name: i.name,
        dueDate: i.dueDate,
      ),
    );
  }
  out.sort((a, b) => a.fireAt.compareTo(b.fireAt));
  return out.take(max).toList();
}
