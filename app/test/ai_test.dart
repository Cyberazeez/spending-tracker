import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/core/models.dart';
import 'package:spending_tracker/features/ai/ai_aggregates.dart';
import 'package:spending_tracker/features/insights/metrics.dart';

import 'support/fakes.dart';

Txn spend(String id, int halalas, {String? cat, String merchant = 'ACME'}) =>
    Txn(
      id: id,
      type: 'purchase',
      direction: 'out',
      amountHalalas: halalas,
      occurredAt: DateTime.utc(2026, 10, 20, 9),
      merchant: merchant,
      merchantNorm: merchant.toLowerCase(),
      categoryId: cat,
    );

Future<Harness> open(
  WidgetTester tester, {
  bool aiOn = false,
  List<Txn> txns = const [],
  int tab = 0,
}) async {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final h = Harness(signedIn: true);
  h.data.aiOn = aiOn;
  h.data.txns = txns;
  h.data.history = txns;
  await tester.pumpWidget(await h.build());
  await tester.pumpAndSettle();
  return h;
}

void main() {
  group('aggregates', () {
    final cats = [
      const Category(id: 'c1', name: 'Dining'),
      const Category(id: 'c2', name: 'Groceries'),
    ];
    final today = DateTime.utc(2026, 10, 30);

    test('only numbers and the user\'s own category names', () {
      final ins = computeInsights([
        spend('1', 90000, cat: 'c1', merchant: 'Secret Cafe'),
        spend('2', 40000, cat: 'c2'),
      ], DateTime.utc(2026, 10, 30, 12));
      final a = buildAiAggregates(ins, cats, const [
        Budget(id: 'b', categoryId: 'c1', limitHalalas: 100000),
      ], today)!;
      expect(a['month'], '2026-10');
      expect(a['spendHalalas'], 130000);
      final rows = (a['categories'] as List).cast<Map<String, dynamic>>();
      expect(rows.map((r) => r['name']), ['Dining', 'Groceries']);
      expect(rows.first['budgetHalalas'], 100000);
      expect(rows.last['budgetHalalas'], isNull);
      expect(a.toString().toLowerCase().contains('secret'), isFalse);
      expect(a.keys, {
        'month',
        'spendHalalas',
        'lastMonthToDateHalalas',
        'savingsRatePct',
        'salaryAboveBase',
        'subscriptionsMonthlyHalalas',
        'categories',
      });
    });

    test('nothing to say without data', () {
      expect(
        buildAiAggregates(
          computeInsights(const [], DateTime.utc(2026, 10, 30)),
          cats,
          const [],
          today,
        ),
        isNull,
      );
    });

    test('categories the user does not have are left out', () {
      final ins = computeInsights([
        spend('1', 500, cat: 'gone'),
        spend('2', 700, cat: 'c1'),
      ], DateTime.utc(2026, 10, 30, 12));
      final a = buildAiAggregates(ins, cats, const [], today)!;
      expect((a['categories'] as List).length, 1);
    });
  });

  testWidgets('the AI switch in More is off by default and saves', (
    tester,
  ) async {
    final h = await open(tester);
    await tester.tap(find.text('More').last);
    await tester.pumpAndSettle();
    expect(find.text('AI assistant'), findsOneWidget);
    final sw = find.byType(CupertinoSwitch).at(1);
    expect(tester.widget<CupertinoSwitch>(sw).value, isFalse);
    await tester.tap(sw);
    await tester.pumpAndSettle();
    expect(h.data.aiOn, isTrue);
    expect(tester.widget<CupertinoSwitch>(sw).value, isTrue);
  });

  testWidgets('a failed save of the switch snaps back and says so', (
    tester,
  ) async {
    final h = await open(tester);
    h.data.failAiSave = true;
    await tester.tap(find.text('More').last);
    await tester.pumpAndSettle();
    final sw = find.byType(CupertinoSwitch).at(1);
    await tester.tap(sw);
    await tester.pumpAndSettle();
    expect(tester.widget<CupertinoSwitch>(sw).value, isFalse);
    expect(find.textContaining('Could not save'), findsOneWidget);
  });

  testWidgets('incoming money is not counted as needing a category', (
    tester,
  ) async {
    final salary = Txn(
      id: 's',
      type: 'transfer_in',
      direction: 'in',
      amountHalalas: 1000000,
      occurredAt: DateTime.utc(2026, 10, 27, 5),
      merchant: 'Employer',
      merchantNorm: 'employer',
    );
    await open(tester, aiOn: true, txns: [salary]);
    await tester.tap(find.text('Transactions').last);
    await tester.pumpAndSettle();
    expect(find.text('Suggest with AI'), findsNothing);
  });

  testWidgets('Suggest with AI is hidden while AI is off', (tester) async {
    await open(tester, txns: [spend('1', 500)]);
    await tester.tap(find.text('Transactions').last);
    await tester.pumpAndSettle();
    expect(find.text('Suggest with AI'), findsNothing);
  });

  testWidgets('Suggest with AI categorises and reports the count', (
    tester,
  ) async {
    final h = await open(tester, aiOn: true, txns: [spend('1', 500)]);
    await tester.tap(find.text('Transactions').last);
    await tester.pumpAndSettle();
    expect(find.text('1 transactions have no category'), findsOneWidget);
    await tester.tap(find.text('Suggest with AI'));
    await tester.pumpAndSettle();
    expect(h.data.suggestCalls, 1);
    expect(find.textContaining('Categorised 3 transactions'), findsOneWidget);
  });

  testWidgets('AI-categorised rows carry an AI tag and the chip filters them', (
    tester,
  ) async {
    final ai = Txn(
      id: 'a',
      type: 'purchase',
      direction: 'out',
      amountHalalas: 2500,
      occurredAt: DateTime.utc(2026, 10, 29, 9),
      merchant: 'Cafe One',
      merchantNorm: 'cafe one',
      categoryId: 'c-din',
      categorySource: 'ai',
    );
    final manual = Txn(
      id: 'm',
      type: 'purchase',
      direction: 'out',
      amountHalalas: 4000,
      occurredAt: DateTime.utc(2026, 10, 29, 10),
      merchant: 'Market Two',
      merchantNorm: 'market two',
      categoryId: 'c-gro',
      categorySource: 'manual',
    );
    await open(tester, aiOn: true, txns: [ai, manual]);
    await tester.tap(find.text('Transactions').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('Dining · AI'), findsOneWidget);
    expect(find.textContaining('Groceries · AI'), findsNothing);
    await tester.tap(find.text('AI suggested'));
    await tester.pumpAndSettle();
    expect(find.text('Cafe One'), findsOneWidget);
    expect(find.text('Market Two'), findsNothing);
  });

  testWidgets('a used-up AI budget is explained', (tester) async {
    final h = await open(tester, aiOn: true, txns: [spend('1', 500)]);
    h.data.suggestResult = const AiOutcome.fail('cap_reached');
    await tester.tap(find.text('Transactions').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Suggest with AI'));
    await tester.pumpAndSettle();
    expect(find.textContaining('AI budget is used up'), findsOneWidget);
  });

  testWidgets('AI tips card asks for tips and shows them', (tester) async {
    final h = await open(
      tester,
      aiOn: true,
      txns: [spend('1', 90000, cat: 'c-din')],
    );
    h.data.saved = [];
    await tester.tap(find.text('Insights').last);
    await tester.pumpAndSettle();
    expect(find.text('AI tips'), findsOneWidget);
    await tester.tap(find.text('Get tips'));
    await tester.pumpAndSettle();
    expect(h.data.tipCalls, hasLength(1));
    expect(h.data.tipCalls.single.$2, 'en');
    expect(h.data.tipCalls.single.$1['categories'], isNotEmpty);
    expect(find.textContaining('Cut dining'), findsOneWidget);
    expect(find.text('Refresh tips'), findsOneWidget);
  });

  testWidgets('saved tips show without asking again', (tester) async {
    final h = Harness(signedIn: true);
    h.data.aiOn = true;
    h.data.history = [spend('1', 90000, cat: 'c-din')];
    h.data.saved = ['Saved tip: SAR 900 on dining.'];
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(await h.build());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Insights').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('Saved tip'), findsOneWidget);
    expect(h.data.tipCalls, isEmpty);
  });

  testWidgets('the AI tips card is hidden while AI is off', (tester) async {
    await open(tester, txns: [spend('1', 90000, cat: 'c-din')]);
    await tester.tap(find.text('Insights').last);
    await tester.pumpAndSettle();
    expect(find.text('AI tips'), findsNothing);
  });

  for (final lang in ['en', 'ar']) {
    testWidgets('AI cards survive 2x text on a 360pt phone ($lang)', (
      tester,
    ) async {
      final h = Harness(signedIn: true);
      h.data.aiOn = true;
      h.data.txns = [spend('1', 90000), spend('2', 50000, cat: 'c-din')];
      h.data.history = h.data.txns;
      h.data.saved = [
        'Cut dining: SAR 900 vs SAR 600 average, a long tip that wraps.',
      ];
      tester.view.physicalSize = const Size(720, 1280);
      tester.view.devicePixelRatio = 2;
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(() {
        tester.view.reset();
        tester.platformDispatcher.clearAllTestValues();
      });
      await tester.pumpWidget(await h.build(prefs: {'locale': lang}));
      await tester.pumpAndSettle();
      final tabs = lang == 'en'
          ? ['Transactions', 'Insights', 'More']
          : ['العمليات', 'التحليلات', 'المزيد'];
      for (final tab in tabs) {
        await tester.tap(find.text(tab).last);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: tab);
      }
    });
  }
}
