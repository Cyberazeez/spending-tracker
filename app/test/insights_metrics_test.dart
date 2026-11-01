import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/core/models.dart';
import 'package:spending_tracker/features/insights/metrics.dart';

int n = 0;
Txn tx(
  String when, // Riyadh local "yyyy-MM-dd HH:mm"
  int halalas, {
  String type = 'purchase',
  String direction = 'out',
  String? merchant,
  String? cat,
  bool internal = false,
  bool excluded = false,
}) {
  final local = DateTime.parse('${when.replaceFirst(' ', 'T')}:00Z');
  return Txn(
    id: 't${n++}',
    type: type,
    direction: direction,
    amountHalalas: halalas,
    occurredAt: local.subtract(const Duration(hours: 3)),
    merchant: merchant,
    merchantNorm: merchant?.toLowerCase(),
    categoryId: cat,
    isInternal: internal,
    excludedFromSpend: excluded,
  );
}

// "now" = 15 Nov 2026 12:00 Riyadh
final now = DateTime.utc(2026, 11, 15, 9);

void main() {
  test(
    'spend ignores internal, excluded and incoming money; refunds subtract',
    () {
      expect(spendOf(tx('2026-11-01 10:00', 1000)), 1000);
      expect(spendOf(tx('2026-11-01 10:00', 1000, internal: true)), 0);
      expect(spendOf(tx('2026-11-01 10:00', 1000, excluded: true)), 0);
      expect(
        spendOf(tx('2026-11-01 10:00', 1000, direction: 'in', type: 'salary')),
        0,
      );
      expect(
        spendOf(tx('2026-11-01 10:00', 400, direction: 'in', type: 'refund')),
        -400,
      );
    },
  );

  test('month total and same-day comparison use Riyadh calendar days', () {
    final i = computeInsights([
      tx('2026-11-03 10:00', 10000),
      tx('2026-11-15 23:30', 5000), // still the 15th in Riyadh
      tx('2026-10-10 10:00', 7000), // before the 15th: counts
      tx('2026-10-20 10:00', 9000), // after the 15th: does not
      tx('2026-11-04 10:00', 3000, internal: true),
    ], now);
    expect(i.monthSpend, 15000);
    expect(i.lastMonthToDate, 7000);
  });

  test('a late-night UTC transaction belongs to the next Riyadh month', () {
    final late = Txn(
      id: 'x',
      type: 'purchase',
      direction: 'out',
      amountHalalas: 800,
      occurredAt: DateTime.utc(2026, 10, 31, 22, 30), // 1 Nov 01:30 Riyadh
    );
    expect(computeInsights([late], now).monthSpend, 800);
  });

  test('by category sorts by amount; uncategorised is its own bucket', () {
    final i = computeInsights([
      tx('2026-11-02 10:00', 1000, cat: 'gro'),
      tx('2026-11-03 10:00', 4000, cat: 'din'),
      tx('2026-11-04 10:00', 500),
    ], now);
    expect(i.byCategory.map((c) => (c.categoryId, c.halalas)), [
      ('din', 4000),
      ('gro', 1000),
      (null, 500),
    ]);
  });

  test('top merchants are summed and capped at five', () {
    final i = computeInsights([
      for (var k = 0; k < 7; k++)
        tx('2026-11-0${k + 1} 10:00', 1000 * (k + 1), merchant: 'm$k'),
      tx('2026-11-09 10:00', 500, merchant: 'm6'),
    ], now);
    expect(i.topMerchants.length, 5);
    expect(i.topMerchants.first.merchantNorm, 'm6');
    expect(i.topMerchants.first.halalas, 7500);
    expect(i.topMerchants.first.count, 2);
  });

  test('3-month average and spikes need history, a 1.5x jump and 200 SAR', () {
    final history = [
      tx('2026-10-05 10:00', 30000, cat: 'din'),
      tx('2026-09-05 10:00', 30000, cat: 'din'),
      tx('2026-08-05 10:00', 30000, cat: 'din'),
    ];
    final spike = computeInsights([
      ...history,
      tx('2026-11-05 10:00', 60000, cat: 'din'),
    ], now);
    expect(spike.average3['din'], 30000);
    expect(spike.spikes.single.categoryId, 'din');

    final small = computeInsights([
      ...history,
      tx('2026-11-05 10:00', 40000, cat: 'din'), // only 1.33x
    ], now);
    expect(small.spikes, isEmpty);

    final tiny = computeInsights([
      tx('2026-10-05 10:00', 3000, cat: 'x'),
      tx('2026-11-05 10:00', 9000, cat: 'x'), // 3x but only 60 SAR over
    ], now);
    expect(tiny.spikes, isEmpty);

    final noHistory = computeInsights([
      tx('2026-11-05 10:00', 90000, cat: 'din'),
    ], now);
    expect(noHistory.spikes, isEmpty);
  });

  test('subscriptions: same merchant, once a month, near-identical amount', () {
    Txn nf(String d, int a) => tx(d, a, merchant: 'netflix');
    final i = computeInsights([
      nf('2026-08-12 09:00', 5500),
      nf('2026-09-12 09:00', 5500),
      nf('2026-10-12 09:00', 5600),
      nf('2026-11-12 09:00', 5500),
      // weekly coffee: several per month, never a subscription
      for (var k = 1; k < 28; k += 7)
        tx(
          '2026-10-${k.toString().padLeft(2, '0')} 08:00',
          1500,
          merchant: 'cafe',
        ),
      for (var k = 1; k < 28; k += 7)
        tx(
          '2026-09-${k.toString().padLeft(2, '0')} 08:00',
          1500,
          merchant: 'cafe',
        ),
      // twice only: not enough
      tx('2026-10-01 10:00', 2000, merchant: 'gym'),
      tx('2026-11-01 10:00', 2000, merchant: 'gym'),
      // varying amounts: groceries
      tx('2026-09-02 10:00', 5000, merchant: 'shop'),
      tx('2026-10-02 10:00', 9000, merchant: 'shop'),
      tx('2026-11-02 10:00', 2000, merchant: 'shop'),
    ], now);
    expect(i.subscriptions.map((s) => s.merchantNorm), ['netflix']);
    expect(i.subscriptions.single.monthlyHalalas, 5500);
    expect(i.subscriptionsMonthly, 5500);
  });

  test('savings rate and the salary-above-base flag', () {
    final ok = computeInsights([
      tx('2026-11-01 08:00', 1410000, type: 'salary', direction: 'in'),
      tx('2026-11-02 10:00', 410000),
    ], now);
    expect(ok.salary, 1410000);
    expect(ok.savingsRate, closeTo(0.709, 0.001));
    expect(ok.salaryAboveBase, isFalse);

    final high = computeInsights([
      tx('2026-11-01 08:00', 1500000, type: 'salary', direction: 'in'),
    ], now);
    expect(high.salaryAboveBase, isTrue);

    final none = computeInsights([tx('2026-11-02 10:00', 1000)], now);
    expect(none.savingsRate, isNull);
    expect(none.salaryAboveBase, isFalse);
  });

  test(
    'excluded categories are not spending; negative categories are hidden',
    () {
      final i = computeInsights(
        [
          tx('2026-11-02 10:00', 5000, cat: 'transfers'),
          tx('2026-11-03 10:00', 2000, cat: 'din'),
          tx('2026-11-04 10:00', 3000, direction: 'in', type: 'refund'),
        ],
        now,
        excludedCategories: {'transfers'},
      );
      expect(i.monthSpend, -1000);
      expect(i.byCategory.map((c) => c.categoryId), ['din']);
    },
  );

  test('the average divides by the months that have data, not always 3', () {
    final i = computeInsights([
      tx('2026-10-05 10:00', 90000, cat: 'fuel'),
      tx('2026-11-05 10:00', 60000, cat: 'fuel'),
    ], now);
    expect(i.average3['fuel'], 90000);
    expect(i.spikes, isEmpty);
  });

  test('budget levels: ok below 80%, warn from 80%, over from 100%', () {
    expect(budgetLevel(7999, 10000), BudgetLevel.ok);
    expect(budgetLevel(8000, 10000), BudgetLevel.warn);
    expect(budgetLevel(9999, 10000), BudgetLevel.warn);
    expect(budgetLevel(10000, 10000), BudgetLevel.over);
    expect(budgetLevel(50000, 10000), BudgetLevel.over);
    expect(budgetLevel(100, 0), BudgetLevel.ok);
  });
}
