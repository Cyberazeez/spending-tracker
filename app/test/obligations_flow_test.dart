import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/core/models.dart';

import 'package:spending_tracker/ui/tokens.dart';

import 'support/fakes.dart';

ObligationInstance inst(
  String id,
  String name,
  String due, {
  String status = 'pending',
  int expected = 18000,
  String matchState = 'none',
  // The cycle (issue month). The test clock is 30 Oct, so October is "this month".
  String period = '2026-10-01',
}) => ObligationInstance(
  id: id,
  obligationId: 'o-$id',
  name: name,
  kind: 'fixed',
  periodStart: DateTime.parse('${period}T00:00:00Z'),
  dueDate: DateTime.parse('${due}T00:00:00Z'),
  status: status,
  expectedHalalas: expected,
  matchState: matchState,
);

Future<Harness> open(WidgetTester tester, List<ObligationInstance> list) async {
  final h = Harness(signedIn: true);
  h.data.instances = list;
  h.data.monthSpend = 500000;
  // 2026-10-30 12:00 UTC is 15:00 in Riyadh
  await tester.pumpWidget(await h.build());
  await tester.pumpAndSettle();
  await tester.tap(find.text('Bills').last);
  await tester.pumpAndSettle();
  return h;
}

void main() {
  testWidgets('upcoming lists what is due soon with a committed total', (
    tester,
  ) async {
    final h = await open(tester, [
      inst('1', 'Horse and foal', '2026-10-31'),
      inst('2', 'Murabahah', '2026-10-31', expected: 385833),
      inst('3', 'Old one', '2026-09-28', period: '2026-09-01'),
    ]);
    expect(h.data.refreshCalls, greaterThan(0));
    expect(find.text('October · still to pay'), findsOneWidget);
    expect(find.text('Horse and foal'), findsOneWidget);
    expect(find.text('Murabahah'), findsOneWidget);
    // an open item from an earlier cycle is not a row of this month: it is named once, in the reminder card
    expect(find.text('1 unpaid from an earlier month'), findsOneWidget);
    expect(find.text('Old one'), findsOneWidget);
    expect(
      find.text('Pending'),
      findsNWidgets(2),
    ); // only the two of this month
    expect(find.text('⃁ 4,038.33'), findsOneWidget); // 180.00 + 3,858.33
  });

  testWidgets(
    'bills are grouped by cycle: this month, then next month folded',
    (tester) async {
      await open(tester, [
        inst('1', 'House Card', '2026-10-31'),
        // issued in October, due in November: still this month's cycle
        inst('2', 'Horse and foal', '2026-10-31'),
        inst('3', 'Murabahah', '2026-11-28', period: '2026-11-01'),
        inst('4', 'Far one', '2026-11-29', period: '2026-11-01'),
      ]);
      expect(find.text('This month · October'), findsOneWidget);
      expect(find.text('Next month · November'), findsOneWidget);
      expect(find.text('House Card'), findsOneWidget);
      expect(find.text('Horse and foal'), findsOneWidget);
      // next month is one folded line until it is tapped
      expect(find.text('2 bills'), findsOneWidget);
      expect(find.text('Murabahah'), findsNothing);
      await tester.tap(find.text('2 bills'));
      await tester.pumpAndSettle();
      expect(find.text('Murabahah'), findsOneWidget);
      expect(find.text('Far one'), findsOneWidget);
    },
  );

  testWidgets('the cycle card shows what is paid and what is left', (
    tester,
  ) async {
    await open(tester, [
      inst('1', 'House Card', '2026-10-02', status: 'paid', expected: 50000),
      inst('2', 'Murabahah', '2026-10-28', expected: 385833),
    ]);
    expect(find.text('⃁ 3,858.33'), findsOneWidget); // still to pay
    expect(find.textContaining('1 of 2 bills'), findsOneWidget);
    // the paid one stays visible in its own month, after the open ones
    expect(
      tester.getTopLeft(find.text('Murabahah')).dy,
      lessThan(tester.getTopLeft(find.text('House Card')).dy),
    );
  });

  testWidgets('a bill with a usual range shows the range, not one figure', (
    tester,
  ) async {
    final range = ObligationInstance(
      id: 'e',
      obligationId: 'o-e',
      name: 'Electricity (SEC)',
      kind: 'bill',
      periodStart: DateTime.utc(2026, 10),
      dueDate: DateTime.utc(2026, 10, 28),
      status: 'pending',
      expectedHalalas: 69200,
      usualMinHalalas: 65800,
      usualMaxHalalas: 72600,
    );
    await open(tester, [range]);
    // a row shows only the amount, in bold: no due date, no "Expected", no usual range
    expect(find.textContaining('⃁ 692.00'), findsWidgets);
    expect(find.textContaining('Usually'), findsNothing);
    expect(find.textContaining('Expected'), findsNothing);
    expect(find.textContaining('Due '), findsNothing);
  });

  testWidgets('an amount can be edited by hand', (tester) async {
    final h = await open(tester, [inst('1', 'Electricity', '2026-10-31')]);
    await tester.tap(find.text('Electricity'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit amount'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(CupertinoTextField), '700.50');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(h.data.instanceCalls, contains('amount:1:70050'));
    expect(find.textContaining('⃁ 700.50'), findsWidgets);
  });

  testWidgets('the progress bar fill is the solid accent green', (
    tester,
  ) async {
    await open(tester, [
      inst('1', 'Paid one', '2026-10-31', status: 'paid', expected: 30000),
      inst('2', 'Open one', '2026-10-31', expected: 10000),
    ]);
    final fill = tester.widget<ColoredBox>(
      find.byKey(const ValueKey('cycle-bar-fill')),
    );
    expect(fill.color.toARGB32(), AppTokens.accent.color.toARGB32());
    final fillW = tester.getSize(find.byKey(const ValueKey('cycle-bar-fill')));
    final barW = tester.getSize(find.byType(LayoutBuilder).last).width;
    expect(fillW.width / barW, closeTo(0.75, 0.01)); // 300 of 400 paid
  });

  testWidgets('history is grouped by month, newest first', (tester) async {
    await open(tester, [
      inst('1', 'Paid Oct', '2026-10-02', status: 'paid', period: '2026-10-01'),
      inst('2', 'Paid Sep', '2026-09-28', status: 'paid', period: '2026-09-01'),
      inst(
        '3',
        'Paid Oct late',
        '2026-10-28',
        status: 'paid',
        period: '2026-10-01',
      ),
    ]);
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    expect(find.textContaining('October'), findsOneWidget);
    expect(find.textContaining('September'), findsOneWidget);
    expect(
      tester.getTopLeft(find.textContaining('October')).dy,
      lessThan(tester.getTopLeft(find.textContaining('September')).dy),
    );
  });

  testWidgets('an invalid edited amount is refused', (tester) async {
    final h = await open(tester, [inst('1', 'Electricity', '2026-10-31')]);
    await tester.tap(find.text('Electricity'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit amount'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(CupertinoTextField), '12,50');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Enter an amount like'), findsOneWidget);
    expect(h.data.instanceCalls.where((c) => c.startsWith('amount')), isEmpty);
  });

  testWidgets('overdue and history segments', (tester) async {
    await open(tester, [
      inst('1', 'Old one', '2026-10-01'),
      inst('2', 'Paid one', '2026-10-02', status: 'paid'),
    ]);
    await tester.tap(find.text('Overdue').first);
    await tester.pumpAndSettle();
    expect(find.text('Old one'), findsOneWidget);
    expect(find.text('Paid one'), findsNothing);
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    expect(find.text('Paid one'), findsOneWidget);
  });

  testWidgets('mark paid from the row actions moves it to history', (
    tester,
  ) async {
    final h = await open(tester, [inst('1', 'Horse and foal', '2026-10-31')]);
    await tester.tap(find.text('Horse and foal'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mark as paid'));
    await tester.pumpAndSettle();
    expect(h.data.instanceCalls, ['paid:1']);
    // it stays in this month's list, now as paid
    expect(find.text('Paid'), findsWidgets);
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    expect(find.text('Horse and foal'), findsOneWidget);
  });

  testWidgets('a suggested payment can be confirmed or rejected', (
    tester,
  ) async {
    final h = await open(tester, [
      inst('1', 'Internet', '2026-10-31', matchState: 'suggested'),
    ]);
    expect(
      find.textContaining('Mark "Internet" as paid with this payment?'),
      findsOneWidget,
    );
    await tester.tap(find.text('Not this'));
    await tester.pumpAndSettle();
    expect(h.data.instanceCalls, ['reject:1']);
    expect(find.textContaining('with this payment?'), findsNothing);
  });

  testWidgets('confirming a suggestion marks it paid', (tester) async {
    final h = await open(tester, [
      inst('1', 'Internet', '2026-10-31', matchState: 'suggested'),
    ]);
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(h.data.instanceCalls, ['confirm:1']);
    expect(h.data.instances.first.status, 'paid');
  });

  testWidgets('the card statement row shows only its amount', (tester) async {
    final h = Harness(signedIn: true);
    h.data.instances = [
      ObligationInstance(
        id: 'st',
        obligationId: 'o-st',
        name: 'Credit card 8119 statement',
        kind: 'card_statement',
        periodStart: DateTime.utc(2026, 11),
        dueDate: DateTime.utc(2026, 11, 25),
        status: 'pending',
        expectedHalalas: 846323,
        plan: const InstalmentPlan(
          name: 'Autopia',
          instalmentHalalas: 165350,
          months: 6,
          firstYear: 2026,
          firstMonth: 10,
        ),
      ),
    ];
    await tester.pumpWidget(await h.build());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bills').last);
    await tester.pumpAndSettle();
    // the November statement is next month's cycle on 30 Oct: open the folded line
    await tester.tap(find.text('1 bill'));
    await tester.pumpAndSettle();
    // only the amount is shown on the row, the plan note is gone
    expect(find.textContaining('⃁ 8,463.23'), findsOneWidget);
    expect(find.textContaining('Includes Autopia'), findsNothing);
  });

  test('instalment plan numbering stays inside the plan', () {
    const plan = InstalmentPlan(
      name: 'x',
      instalmentHalalas: 1,
      months: 6,
      firstYear: 2026,
      firstMonth: 10,
    );
    expect(plan.numberFor(DateTime.utc(2026, 9)), isNull);
    expect(plan.numberFor(DateTime.utc(2026, 10)), 1);
    expect(plan.numberFor(DateTime.utc(2027, 1)), 4);
    expect(plan.numberFor(DateTime.utc(2027, 3)), 6);
    expect(plan.numberFor(DateTime.utc(2027, 4)), isNull);
    expect(InstalmentPlan.fromJson({'first': 'bad'}), isNull);
    expect(InstalmentPlan.fromJson(null), isNull);
  });

  testWidgets('a failed load shows retry', (tester) async {
    final h = Harness(signedIn: true);
    h.data.failLoad = true;
    await tester.pumpWidget(await h.build());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bills').last);
    await tester.pumpAndSettle();
    expect(find.text('Could not load. Pull to retry.'), findsOneWidget);
  });

  testWidgets('arabic labels and RTL amounts', (tester) async {
    final h = Harness(signedIn: true);
    h.data.instances = [inst('1', 'Horse', '2026-10-31')];
    await tester.pumpWidget(await h.build(prefs: {'locale': 'ar'}));
    await tester.pumpAndSettle();
    await tester.tap(find.text('الفواتير').last);
    await tester.pumpAndSettle();
    expect(find.text('القادمة'), findsOneWidget);
    expect(find.textContaining('المتوقع'), findsNothing);
  });

  for (final lang in ['en', 'ar']) {
    testWidgets(
      'the Bills cycle layout survives 2x text on a 360pt phone ($lang)',
      (tester) async {
        tester.view.physicalSize = const Size(720, 1280);
        tester.view.devicePixelRatio = 2;
        tester.platformDispatcher.textScaleFactorTestValue = 2.0;
        addTearDown(() {
          tester.view.reset();
          tester.platformDispatcher.clearAllTestValues();
        });
        final h = Harness(signedIn: true);
        h.data.instances = [
          inst('1', 'Horse and foal', '2026-10-31'),
          inst('2', 'Old one', '2026-09-28', period: '2026-09-01'),
          inst('3', 'Murabahah', '2026-11-28', period: '2026-11-01'),
        ];
        await tester.pumpWidget(await h.build(prefs: {'locale': lang}));
        await tester.pumpAndSettle();
        await tester.tap(find.text(lang == 'en' ? 'Bills' : 'الفواتير').last);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }
}
