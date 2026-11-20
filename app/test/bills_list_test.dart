import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/core/models.dart';
import 'package:spending_tracker/features/obligations/logic.dart';

ObligationInstance _i(
  String id,
  String due, {
  String period = '2026-10-01',
  String status = 'pending',
}) => ObligationInstance(
  id: id,
  obligationId: 'o-$id',
  name: id,
  kind: 'fixed',
  periodStart: DateTime.parse('${period}T00:00:00Z'),
  dueDate: DateTime.parse('${due}T00:00:00Z'),
  status: status,
  expectedHalalas: 1000,
);

void main() {
  final today = DateTime.utc(2026, 10, 30);
  List<String> ids(List<ObligationInstance> l) => [for (final i in l) i.id];

  test('this month always, earlier months only while open, next month within 7 days', () {
    final all = [
      _i('paidNow', '2026-10-05', status: 'paid'),
      _i('openNow', '2026-10-31'),
      _i('skippedNow', '2026-10-20', status: 'skipped'),
      _i('oldOpen', '2026-09-10', period: '2026-09-01'),
      _i('oldPaid', '2026-09-10', period: '2026-09-01', status: 'paid'),
      _i('next7', '2026-11-06', period: '2026-11-01'),
      _i('next8', '2026-11-07', period: '2026-11-01'),
      _i('nextPaid', '2026-11-02', period: '2026-11-01', status: 'paid'),
      _i('later', '2026-12-01', period: '2026-12-01'),
    ];
    expect(ids(billsList(all, today)), [
      'oldOpen',
      'openNow',
      'next7',
      'paidNow',
    ]);
  });

  test('history is every bill from an earlier month, newest first', () {
    final all = [
      _i('now', '2026-10-05'),
      _i('aug', '2026-08-10', period: '2026-08-01', status: 'paid'),
      _i('sep', '2026-09-10', period: '2026-09-01'),
    ];
    expect(ids(billsHistory(all, today)), ['sep', 'aug']);
  });

  test('days until due counts whole days from today', () {
    expect(daysUntilDue(_i('a', '2026-11-06'), today), 7);
    expect(daysUntilDue(_i('b', '2026-10-30'), today), 0);
    expect(daysUntilDue(_i('c', '2026-10-28'), today), -2);
  });
}
