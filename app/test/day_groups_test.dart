import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/core/models.dart';
import 'package:spending_tracker/features/transactions/day_groups.dart';

Txn tx(
  String id,
  String utc,
  int halalas, {
  String direction = 'out',
  String type = 'purchase',
  bool internal = false,
}) => Txn(
  id: id,
  type: type,
  direction: direction,
  amountHalalas: halalas,
  occurredAt: DateTime.parse('${utc}Z'),
  isInternal: internal,
  excludedFromSpend: internal,
);

void main() {
  test('groups by Riyadh day, keeps order, newest day first as given', () {
    final groups = groupByDay([
      tx('a', '2026-10-30T10:00:00', 1000),
      tx('b', '2026-10-30T06:00:00', 500),
      tx('c', '2026-10-29T10:00:00', 700),
    ]);
    expect(groups.map((g) => g.day).toList(), [
      DateTime.utc(2026, 10, 30),
      DateTime.utc(2026, 10, 29),
    ]);
    expect(groups.first.items.map((t) => t.id).toList(), ['a', 'b']);
    expect(groups.first.spendHalalas, 1500);
  });

  test('the Riyadh midnight decides the day, not UTC', () {
    // 21:30 UTC on the 29th is 00:30 Riyadh on the 30th.
    final groups = groupByDay([
      tx('late', '2026-10-29T21:30:00', 100),
      tx('before', '2026-10-29T20:30:00', 200),
    ]);
    expect(groups.map((g) => g.day).toList(), [
      DateTime.utc(2026, 10, 30),
      DateTime.utc(2026, 10, 29),
    ]);
  });

  test('day total ignores internal moves and income, refunds subtract, never below 0', () {
    final g = groupByDay([
      tx('buy', '2026-10-30T10:00:00', 1000),
      tx('int', '2026-10-30T10:01:00', 5000, internal: true),
      tx('sal', '2026-10-30T10:02:00', 9000, direction: 'in', type: 'salary'),
      tx('ref', '2026-10-30T10:03:00', 300, direction: 'in', type: 'refund'),
    ]).single;
    expect(g.spendHalalas, 700);
    final only = groupByDay([
      tx('buy', '2026-10-30T10:00:00', 100),
      tx('ref', '2026-10-30T10:03:00', 900, direction: 'in', type: 'refund'),
    ]).single;
    expect(only.spendHalalas, 0);
  });

  test('empty list gives no groups', () {
    expect(groupByDay(const []), isEmpty);
  });
}
