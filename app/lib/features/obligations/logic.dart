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
      // A suggested payment is not confirmed yet, so it does not reduce what is still to pay.
      ((i.expectedHalalas ?? 0) -
              (i.matchState == 'suggested' ? 0 : (i.actualHalalas ?? 0)))
          .clamp(0, 1 << 40),
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
        id: _stableId(i.id),
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

/// FNV-1a: the same id gives the same notification id on every run (String.hashCode does not promise that).
int _stableId(String s) {
  var h = 0x811c9dc5;
  for (final c in s.codeUnits) {
    h = ((h ^ c) * 0x01000193) & 0x7fffffff;
  }
  return h;
}

/// A month of instances: [monthStart] is the first of the month (UTC midnight of a Riyadh date).
class MonthGroup {
  const MonthGroup(this.monthStart, this.items);
  final DateTime monthStart;
  final List<ObligationInstance> items;
}

/// Groups an already sorted list by the month of the due date, keeping the order.
List<MonthGroup> groupByMonth(List<ObligationInstance> rows, DateTime today) {
  final out = <MonthGroup>[];
  for (final i in rows) {
    final start = DateTime.utc(i.dueDate.year, i.dueDate.month);
    if (out.isEmpty || out.last.monthStart != start) {
      out.add(MonthGroup(start, []));
    }
    out.last.items.add(i);
  }
  return out;
}

/// The billing cycle an instance belongs to.
/// A bill with a known issue day goes by its issue date: issued on the 1st to the 19th it belongs to that month,
/// issued on the 20th or later it moves to the next month (STC is issued on the 27th, so it is next month's bill).
/// Anything else (loan, card, fixed payments) goes by the month it is due.
DateTime cycleOf(ObligationInstance i) {
  final issue = i.issueDay;
  final p = i.periodStart;
  if (issue != null && p != null) {
    return DateTime.utc(p.year, p.month + (issue >= 20 ? 1 : 0));
  }
  return DateTime.utc(i.dueDate.year, i.dueDate.month);
}

DateTime currentCycle(DateTime today) => DateTime.utc(today.year, today.month);

DateTime nextCycle(DateTime today) => DateTime.utc(today.year, today.month + 1);

/// Still open (not paid or skipped) and from a cycle before the current one: it was missed, whatever its grace days say.
bool isLeftover(ObligationInstance i, DateTime today) {
  final s = effectiveStatus(i, today);
  return (s == 'pending' || s == 'overdue') &&
      cycleOf(i).isBefore(currentCycle(today));
}

/// Everything that belongs to [cycle] except skipped ones: open items first (by due date), then the paid ones.
List<ObligationInstance> cycleRows(
  List<ObligationInstance> all,
  DateTime cycle,
  DateTime today,
) {
  final out = all
      .where((i) => i.status != 'skipped' && cycleOf(i) == cycle)
      .toList();
  int rank(ObligationInstance i) => effectiveStatus(i, today) == 'paid' ? 1 : 0;
  out.sort((a, b) {
    final r = rank(a).compareTo(rank(b));
    return r != 0 ? r : a.dueDate.compareTo(b.dueDate);
  });
  return out;
}

/// The Overdue tab: past due plus anything left open from an earlier cycle. Oldest first.
List<ObligationInstance> overdueRows(
  List<ObligationInstance> all,
  DateTime today,
) {
  final out = all
      .where(
        (i) => effectiveStatus(i, today) == 'overdue' || isLeftover(i, today),
      )
      .toList();
  out.sort((a, b) => a.dueDate.compareTo(b.dueDate));
  return out;
}

class CycleSummary {
  const CycleSummary({
    required this.stillHalalas,
    required this.paidHalalas,
    required this.paidCount,
    required this.count,
  });

  /// Open items' expected amounts less what was already matched (unknown amounts count as zero).
  final int stillHalalas;
  final int paidHalalas;
  final int paidCount;
  final int count;
  int get totalHalalas => stillHalalas + paidHalalas;
}

/// The numbers of the Bills hero card. A credit card statement is left out: it already adds up the purchases and
/// bills of the month before, so counting it would count the same money twice. Its row is still listed.
CycleSummary summarizeCycle(List<ObligationInstance> all, DateTime today) {
  final rows = all.where((i) => i.kind != 'card_statement').toList();
  var still = 0;
  var paid = 0;
  var paidCount = 0;
  for (final i in rows) {
    if (effectiveStatus(i, today) == 'paid') {
      paid += i.actualHalalas ?? i.expectedHalalas ?? 0;
      paidCount++;
    } else {
      still +=
          ((i.expectedHalalas ?? 0) -
                  (i.matchState == 'suggested' ? 0 : (i.actualHalalas ?? 0)))
              .clamp(0, 1 << 40);
    }
  }
  return CycleSummary(
    stillHalalas: still,
    paidHalalas: paid,
    paidCount: paidCount,
    count: rows.length,
  );
}
