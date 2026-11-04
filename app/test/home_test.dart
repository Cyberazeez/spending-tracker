import 'package:flutter/widgets.dart' show Size;
import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/core/models.dart';
import 'package:spending_tracker/features/home/logic.dart';

import 'support/fakes.dart';

// The harness clock is 2026-10-30 12:00 UTC (15:00 Riyadh).
Txn tx(String id, String when, int h, {String? cat, String? merchant}) => Txn(
  id: id,
  type: 'purchase',
  direction: 'out',
  amountHalalas: h,
  occurredAt: DateTime.parse('${when}Z'),
  merchant: merchant,
  merchantNorm: merchant?.toLowerCase(),
  categoryId: cat,
);

ObligationInstance ob(
  String id,
  String name,
  String due, {
  int amount = 18000,
}) => ObligationInstance(
  id: id,
  obligationId: 'o-$id',
  name: name,
  kind: 'fixed',
  dueDate: DateTime.parse('${due}T00:00:00Z'),
  status: 'pending',
  expectedHalalas: amount,
);

/// Home is a lazy scrolling list; a tall window builds all of it so lower sections can be found.
void tall(WidgetTester t) {
  t.view.physicalSize = const Size(800, 3000);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

void main() {
  test('silence: null when nothing ever arrived, and under the threshold', () {
    final now = DateTime.utc(2026, 11, 10, 12);
    expect(silentDays(const [], now), isNull);
    expect(silentDays([const SenderGap(sender: 'a')], now), isNull);
    expect(
      silentDays([
        SenderGap(sender: 'a', lastReceivedAt: DateTime.utc(2026, 11, 8, 13)),
      ], now),
      isNull,
    );
    expect(
      silentDays([
        SenderGap(sender: 'a', lastReceivedAt: DateTime.utc(2026, 11, 7, 12)),
      ], now),
      3,
    );
  });

  test('silence uses the newest message from any sender', () {
    final now = DateTime.utc(2026, 11, 10, 12);
    expect(
      silentDays([
        SenderGap(sender: 'a', lastReceivedAt: DateTime.utc(2026, 10, 1)),
        SenderGap(sender: 'b', lastReceivedAt: DateTime.utc(2026, 11, 10, 9)),
      ], now),
      isNull,
    );
  });

  testWidgets('a new install shows the waiting-for-SMS state', (tester) async {
    await tester.pumpWidget(await Harness(signedIn: true).build());
    await tester.pumpAndSettle();
    expect(find.text('Waiting for your first SMS'), findsOneWidget);
  });

  testWidgets(
    'home shows this month, the top category, budget alerts and what is next',
    (tester) async {
      tall(tester);
      final h = Harness(signedIn: true)
        ..data.history = [
          tx(
            '1',
            '2026-10-05T09:00:00',
            90000,
            cat: 'c-din',
            merchant: 'Otten',
          ),
          tx('2', '2026-10-06T09:00:00', 30000, cat: 'c-gro', merchant: 'Lulu'),
        ]
        ..data.budgetList = [
          const Budget(id: 'b', categoryId: 'c-din', limitHalalas: 100000),
        ]
        ..data.instances = [
          ob('1', 'Horse and foal', '2026-11-05', amount: 180000),
          ob('2', 'Internet', '2026-11-02'),
          ob('3', 'Mobile', '2026-11-03'),
          ob('4', 'Card', '2026-11-20'),
        ]
        ..data.gaps = [
          SenderGap(
            sender: 'alinma',
            lastReceivedAt: DateTime.utc(2026, 10, 30, 8),
          ),
        ]
        ..data.review = [
          RawMessage(
            id: 'r',
            sender: 'x',
            body: 'b',
            receivedAt: DateTime.utc(2026, 10, 30),
          ),
        ];
      await tester.pumpWidget(await h.build());
      await tester.pumpAndSettle();
      expect(find.text('⃁ 1,200.00'), findsWidgets); // hero and the Food row
      expect(
        find.text('Food'),
        findsOneWidget,
      ); // Dining and Groceries are one group
      expect(find.text('Dining is at 90% of its budget'), findsOneWidget);
      // only the next three, soonest first
      expect(find.text('Internet'), findsOneWidget);
      expect(find.text('Mobile'), findsOneWidget);
      expect(find.text('Horse and foal'), findsOneWidget);
      expect(find.text('Card'), findsNothing);
      expect(find.text('1 to review'), findsOneWidget);
      expect(find.textContaining('No SMS for'), findsNothing);
    },
  );

  testWidgets('home shows spent today and the monthly budget used', (
    tester,
  ) async {
    final h = Harness(signedIn: true)
      ..data.todaySpend = 4500
      ..data.monthlyBudget = 800000
      ..data.history = [
        tx('1', '2026-10-05T09:00:00', 90000, cat: 'c-din', merchant: 'Otten'),
        tx('2', '2026-10-06T09:00:00', 30000, cat: 'c-gro', merchant: 'Lulu'),
      ];
    await tester.pumpWidget(await h.build());
    await tester.pumpAndSettle();
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('⃁ 45.00'), findsOneWidget);
    expect(find.text('15%'), findsOneWidget); // 1,200 of 8,000 (the ring)
    expect(
      find.textContaining(RegExp(r'⃁ 8,000\.00.* budget')),
      findsOneWidget,
    );
  });

  testWidgets(
    'with no spending last month Home says there is nothing to compare',
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
      await tester.pumpWidget(await h.build());
      await tester.pumpAndSettle();
      expect(find.text('—'), findsOneWidget); // nothing to compare with
      expect(find.textContaining('higher'), findsNothing);
    },
  );

  testWidgets('with spending last month Home compares as before', (
    tester,
  ) async {
    final h = Harness(signedIn: true)
      ..data.history = [
        tx('1', '2026-10-05T09:00:00', 90000, cat: 'c-din', merchant: 'Otten'),
        tx('2', '2026-09-05T09:00:00', 40000, cat: 'c-din', merchant: 'Otten'),
      ];
    await tester.pumpWidget(await h.build());
    await tester.pumpAndSettle();
    expect(find.textContaining('125%'), findsOneWidget); // 900 against 400
    expect(find.textContaining('higher'), findsOneWidget);
    expect(find.text('—'), findsNothing);
  });

  testWidgets('the monthly budget warns at 80% and says when it is passed', (
    tester,
  ) async {
    final warn = Harness(signedIn: true)
      ..data.monthlyBudget = 140000
      ..data.history = [
        tx('1', '2026-10-05T09:00:00', 120000, cat: 'c-din', merchant: 'Otten'),
      ];
    await tester.pumpWidget(await warn.build());
    await tester.pumpAndSettle();
    expect(find.text('Monthly budget at 85%'), findsOneWidget);

    final over = Harness(signedIn: true)
      ..data.monthlyBudget = 100000
      ..data.history = [
        tx('1', '2026-10-05T09:00:00', 120000, cat: 'c-din', merchant: 'Otten'),
      ];
    await tester.pumpWidget(await over.build());
    await tester.pumpAndSettle();
    expect(find.text('Over the monthly budget'), findsOneWidget);
  });

  testWidgets('no SMS for days shows a warning', (tester) async {
    final h = Harness(signedIn: true)
      ..data.history = [
        tx('1', '2026-10-05T09:00:00', 1000, cat: 'c-din', merchant: 'Otten'),
      ]
      ..data.gaps = [
        SenderGap(
          sender: 'alinma',
          lastReceivedAt: DateTime.utc(2026, 10, 24, 8),
        ),
      ];
    await tester.pumpWidget(await h.build());
    await tester.pumpAndSettle();
    expect(find.textContaining('No SMS for 6 days'), findsOneWidget);
  });

  testWidgets('an overdue obligation is listed first and marked overdue', (
    tester,
  ) async {
    tall(tester);
    final h = Harness(signedIn: true)
      ..data.history = [
        tx('1', '2026-10-05T09:00:00', 1000, cat: 'c-din', merchant: 'Otten'),
      ]
      ..data.instances = [
        ob('1', 'Internet', '2026-11-02'),
        ob('2', 'Old bill', '2026-10-20'),
      ];
    await tester.pumpWidget(await h.build());
    await tester.pumpAndSettle();
    expect(find.textContaining('Overdue'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Old bill')).dx,
      lessThan(tester.getTopLeft(find.text('Internet')).dx),
    );
  });

  testWidgets('arabic home', (tester) async {
    final h = Harness(signedIn: true)
      ..data.history = [
        tx('1', '2026-10-05T09:00:00', 1000, cat: 'c-din', merchant: 'Otten'),
      ];
    await tester.pumpWidget(await h.build(prefs: {'locale': 'ar'}));
    await tester.pumpAndSettle();
    expect(find.text('المصروف هذا الشهر'), findsOneWidget);
  });
}
