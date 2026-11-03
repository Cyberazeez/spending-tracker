import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/core/models.dart';

import 'support/fakes.dart';

// The harness clock is 2026-10-30 12:00 UTC (15:00 Riyadh).
Txn tx(
  String id,
  String when,
  int h, {
  String? cat,
  String? merchant,
  String type = 'purchase',
  String direction = 'out',
}) => Txn(
  id: id,
  type: type,
  direction: direction,
  amountHalalas: h,
  occurredAt: DateTime.parse('${when}Z'),
  merchant: merchant,
  merchantNorm: merchant?.toLowerCase(),
  categoryId: cat,
);

Future<Harness> open(
  WidgetTester tester,
  Harness h, {
  Map<String, Object> prefs = const {},
}) async {
  // Insights is a lazy scrolling list; a tall window builds all of it so lower cards can be found.
  tester.view.physicalSize = const Size(800, 4000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(await h.build(prefs: prefs));
  await tester.pumpAndSettle();
  await tester.tap(
    find.text(prefs['locale'] == 'ar' ? 'التحليلات' : 'Insights').last,
  );
  await tester.pumpAndSettle();
  return h;
}

void main() {
  testWidgets('empty state before any transaction', (tester) async {
    await open(tester, Harness(signedIn: true));
    expect(find.text('Not enough data yet'), findsOneWidget);
  });

  testWidgets('shows this month, categories, merchants and a savings rate', (
    tester,
  ) async {
    final h = Harness(signedIn: true)
      ..data.history = [
        tx(
          '1',
          '2026-10-05T09:00:00',
          400000,
          cat: 'c-gro',
          merchant: 'Tamimi',
        ),
        tx('2', '2026-10-06T09:00:00', 100000, cat: 'c-din', merchant: 'Otten'),
        tx(
          '3',
          '2026-10-01T05:00:00',
          1410000,
          type: 'salary',
          direction: 'in',
        ),
      ];
    await open(tester, h);
    expect(find.text('SAR 5,000.00'), findsWidgets); // month total
    expect(find.text('Groceries'), findsOneWidget);
    expect(find.text('Tamimi'), findsOneWidget);
    expect(find.text('65%'), findsOneWidget); // (14,100 - 5,000) / 14,100
  });

  testWidgets(
    'the monthly budget can be set, shows percent used, and removed',
    (tester) async {
      final h = Harness(signedIn: true)
        ..data.history = [
          tx(
            '1',
            '2026-10-05T09:00:00',
            90000,
            cat: 'c-din',
            merchant: 'Otten',
          ),
        ];
      await open(tester, h);
      expect(find.text('Not set'), findsOneWidget);
      await tester.tap(find.text('Monthly budget'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Set a budget').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(CupertinoTextField), '3000');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(h.data.instanceCalls, contains('monthlybudget:300000'));
      expect(find.text('30% used'), findsOneWidget); // 900 of 3,000
      await tester.tap(find.text('Monthly budget'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove budget'));
      await tester.pumpAndSettle();
      expect(h.data.instanceCalls, contains('monthlybudget:null'));
      expect(find.text('Not set'), findsOneWidget);
    },
  );

  testWidgets('a budget at 80% or more raises an alert, over 100% says so', (
    tester,
  ) async {
    final h = Harness(signedIn: true)
      ..data.history = [
        tx('1', '2026-10-05T09:00:00', 90000, cat: 'c-din', merchant: 'Otten'),
        tx('2', '2026-10-06T09:00:00', 70000, cat: 'c-gro', merchant: 'Lulu'),
      ]
      ..data.budgetList = [
        const Budget(id: 'b1', categoryId: 'c-din', limitHalalas: 100000),
        const Budget(id: 'b2', categoryId: 'c-gro', limitHalalas: 60000),
      ];
    await open(tester, h);
    expect(find.text('Dining is at 90% of its budget'), findsOneWidget);
    expect(find.text('Groceries is over budget'), findsOneWidget);
  });

  testWidgets('setting a budget validates the amount and saves it', (
    tester,
  ) async {
    final h = Harness(signedIn: true)
      ..data.history = [
        tx('1', '2026-10-05T09:00:00', 90000, cat: 'c-din', merchant: 'Otten'),
      ];
    await open(tester, h);
    await tester.tap(find.text('Dining'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Set a budget').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(CupertinoTextField), '12,50');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Enter an amount like 1500 or 1,500.50'), findsOneWidget);
    await tester.enterText(find.byType(CupertinoTextField), '1,500.50');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(h.data.budgetCalls, ['set:c-din:150050']);
    expect(find.text('of SAR 1,500.50'), findsOneWidget);
  });

  testWidgets('a budget can be created before any spending in that category', (
    tester,
  ) async {
    final h = Harness(signedIn: true)
      ..data.history = [
        tx('1', '2026-10-05T09:00:00', 10000, cat: 'c-din', merchant: 'Otten'),
      ];
    await open(tester, h);
    await tester.tap(find.text('Set a budget').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Groceries').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Set a budget').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(CupertinoTextField), '800');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(h.data.budgetCalls, ['set:c-gro:80000']);
    expect(
      find.text('Groceries'),
      findsOneWidget,
    ); // now listed with its budget
  });

  testWidgets('removing a budget', (tester) async {
    final h = Harness(signedIn: true)
      ..data.history = [
        tx('1', '2026-10-05T09:00:00', 10000, cat: 'c-din', merchant: 'Otten'),
      ]
      ..data.budgetList = [
        const Budget(id: 'b1', categoryId: 'c-din', limitHalalas: 100000),
      ];
    await open(tester, h);
    await tester.tap(find.text('Dining'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove budget'));
    await tester.pumpAndSettle();
    expect(h.data.budgetCalls, ['remove:c-din']);
    expect(find.textContaining('of SAR'), findsNothing);
  });

  testWidgets('a failed load shows retry', (tester) async {
    final h = Harness(signedIn: true)..data.failLoad = true;
    await open(tester, h);
    expect(find.text('Could not load. Pull to retry.'), findsOneWidget);
  });

  testWidgets('arabic labels', (tester) async {
    final h = Harness(signedIn: true)
      ..data.history = [
        tx('1', '2026-10-05T09:00:00', 10000, cat: 'c-din', merchant: 'Otten'),
      ];
    await open(tester, h, prefs: {'locale': 'ar'});
    expect(find.text('المصروف حتى الآن'), findsOneWidget);
    expect(find.text('حسب الفئة'), findsOneWidget);
  });
}
