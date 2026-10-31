import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/core/models.dart';
import 'package:spending_tracker/features/obligations/logic.dart';

ObligationInstance inst(
  String id,
  String due, {
  String status = 'pending',
  int? expected = 10000,
  int? actual,
  int grace = 0,
  int lead = 2,
}) => ObligationInstance(
  id: id,
  obligationId: 'o-$id',
  name: 'Ob $id',
  kind: 'fixed',
  dueDate: DateTime.parse('${due}T00:00:00Z'),
  status: status,
  expectedHalalas: expected,
  actualHalalas: actual,
  graceDays: grace,
  leadDays: lead,
);

DateTime d(String s) => DateTime.parse('${s}T00:00:00Z');

void main() {
  test('riyadhToday: 22:00 UTC is already tomorrow in Riyadh', () {
    expect(riyadhToday(DateTime.utc(2026, 10, 31, 22, 30)), d('2026-11-01'));
    expect(riyadhToday(DateTime.utc(2026, 10, 31, 20, 59)), d('2026-10-31'));
  });

  test(
    'overdue only after due date plus grace; paid and skipped never change',
    () {
      final i = inst('a', '2026-11-28', grace: 3);
      expect(effectiveStatus(i, d('2026-12-01')), 'pending');
      expect(effectiveStatus(i, d('2026-12-02')), 'overdue');
      expect(
        effectiveStatus(inst('b', '2026-11-28'), d('2026-11-28')),
        'pending',
      );
      expect(
        effectiveStatus(inst('b', '2026-11-28'), d('2026-11-29')),
        'overdue',
      );
      expect(
        effectiveStatus(
          inst('c', '2026-01-01', status: 'paid'),
          d('2027-01-01'),
        ),
        'paid',
      );
      expect(
        effectiveStatus(
          inst('c', '2026-01-01', status: 'skipped'),
          d('2027-01-01'),
        ),
        'skipped',
      );
    },
  );

  test('sections: upcoming is pending within 30 days, sorted by due date', () {
    final all = [
      inst('late', '2026-11-20'),
      inst('far', '2027-01-30'),
      inst('soon', '2026-11-02'),
      inst('over', '2026-10-20'),
      inst('done', '2026-10-28', status: 'paid'),
    ];
    final today = d('2026-10-31');
    expect(inSection(all, ObSection.upcoming, today).map((i) => i.id), [
      'soon',
      'late',
    ]);
    expect(inSection(all, ObSection.overdue, today).map((i) => i.id), ['over']);
    expect(inSection(all, ObSection.history, today).map((i) => i.id), ['done']);
  });

  test('committed counts what is still to pay, unknown amounts as zero', () {
    final list = [
      inst('a', '2026-11-02', expected: 17250),
      inst('b', '2026-11-03', expected: 385833, actual: 8700),
      inst('c', '2026-11-04', expected: null),
    ];
    expect(committedHalalas(list), 17250 + 377133);
  });

  test('thisMonth ignores skipped and other months', () {
    final all = [
      inst('a', '2026-11-02'),
      inst('b', '2026-11-28', status: 'skipped'),
      inst('c', '2026-12-02'),
    ];
    expect(thisMonth(all, d('2026-11-15')).map((i) => i.id), ['a']);
  });

  test(
    'reminders: 09:00 Riyadh, lead days before, future only, unpaid only',
    () {
      final now = DateTime.utc(2026, 10, 31, 10);
      final r = planReminders([
        inst(
          'a',
          '2026-11-02',
          lead: 2,
        ), // fires 31 Oct 09:00 Riyadh = 06:00 UTC, already past
        inst('b', '2026-11-05', lead: 2), // 3 Nov 09:00 Riyadh
        inst('c', '2026-11-08', status: 'paid'),
        inst('d', '2026-11-04', lead: 0), // 4 Nov 09:00 Riyadh
      ], now);
      expect(r.map((x) => x.instanceId), ['b', 'd']);
      expect(r.first.fireAt, DateTime.utc(2026, 11, 3, 6));
    },
  );

  test('reminders are capped and stay in time order', () {
    final now = DateTime.utc(2026, 1, 1);
    final many = [
      for (var n = 0; n < 100; n++)
        inst('i$n', '2026-03-${(n % 28 + 1).toString().padLeft(2, '0')}'),
    ];
    final r = planReminders(many, now, max: 60);
    expect(r.length, 60);
    for (var k = 1; k < r.length; k++) {
      expect(r[k].fireAt.isBefore(r[k - 1].fireAt), isFalse);
    }
  });
}
