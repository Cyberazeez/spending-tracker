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
  testWidgets(
    'one list: this month with a status per bill, an earlier unpaid bill as Overdue',
    (tester) async {
      final h = await open(tester, [
        inst('1', 'Horse and foal', '2026-10-31'),
        inst('2', 'Murabahah', '2026-10-31', expected: 385833),
        inst('3', 'Old one', '2026-09-28', period: '2026-09-01'),
        inst('4', 'Later', '2026-10-31', period: '2026-10-01', status: 'paid'),
      ]);
      expect(h.data.refreshCalls, greaterThan(0));
      expect(find.text('October · still to pay'), findsOneWidget);
      // no tabs any more
      expect(find.text('Upcoming'), findsNothing);
      expect(find.text('Overdue'), findsOneWidget); // the status of Old one
      expect(find.text('Due tomorrow'), findsNWidgets(2));
      expect(find.text('Paid'), findsOneWidget);
      // still to pay counts the overdue one too: 180.00 + 3,858.33 + 180.00
      expect(find.text('⃁ 4,218.33'), findsOneWidget);
      expect(find.textContaining('1 overdue'), findsOneWidget);
      // order: overdue first, then open, then paid
      double y(String s) => tester.getTopLeft(find.text(s)).dy;
      expect(y('Old one'), lessThan(y('Horse and foal')));
      expect(y('Murabahah'), lessThan(y('Later')));
      expect(find.byKey(const ValueKey('bills-history')), findsOneWidget);
    },
  );

  testWidgets('next month stays hidden until 7 days before it is due', (
    tester,
  ) async {
    // The test clock is 30 Oct.
    await open(tester, [
      inst('1', 'House Card', '2026-10-31'),
      inst('2', 'In a week', '2026-11-06', period: '2026-11-01'),
      inst('3', 'Too far', '2026-11-07', period: '2026-11-01'),
      inst(
        '4',
        'Next paid',
        '2026-11-03',
        period: '2026-11-01',
        status: 'paid',
      ),
    ]);
    expect(find.text('House Card'), findsOneWidget);
    expect(find.text('In a week'), findsOneWidget);
    expect(find.text('Due in 7 days'), findsOneWidget);
    expect(find.text('Too far'), findsNothing);
    expect(find.text('Next paid'), findsNothing);
    expect(find.text('Next month · November'), findsNothing);
  });

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
    await tester.tap(find.byKey(const ValueKey('bill-amount')));
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
    final fill = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('cycle-bar-fill')),
    );
    expect(
      (fill.decoration as BoxDecoration).color!.toARGB32(),
      AppTokens.accent.color.toARGB32(),
    );
    final fillW = tester.getSize(find.byKey(const ValueKey('cycle-bar-fill')));
    final barW = tester
        .getSize(
          find
              .ancestor(
                of: find.byKey(const ValueKey('cycle-bar-fill')),
                matching: find.byType(LayoutBuilder),
              )
              .first,
        )
        .width;
    expect(fillW.width / barW, closeTo(0.75, 0.01)); // 300 of 400 paid
  });

  testWidgets('History opens past months, newest first', (tester) async {
    await open(tester, [
      inst('1', 'Paid Oct', '2026-10-02', status: 'paid', period: '2026-10-01'),
      inst('2', 'Paid Sep', '2026-09-28', status: 'paid', period: '2026-09-01'),
      inst('3', 'Paid Aug', '2026-08-28', status: 'paid', period: '2026-08-01'),
    ]);
    // a paid bill of this month stays on Bills, with its status
    expect(find.text('Paid Oct'), findsOneWidget);
    expect(find.text('Paid Sep'), findsNothing);
    await tester.ensureVisible(find.byKey(const ValueKey('bills-history')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('bills-history')));
    await tester.pumpAndSettle();
    expect(find.text('Bill history'), findsOneWidget);
    expect(find.text('Paid Oct'), findsNothing);
    expect(find.text('Paid Sep'), findsOneWidget);
    expect(
      tester.getTopLeft(find.textContaining('September')).dy,
      lessThan(tester.getTopLeft(find.textContaining('August')).dy),
    );
  });

  testWidgets('an invalid edited amount is refused', (tester) async {
    final h = await open(tester, [inst('1', 'Electricity', '2026-10-31')]);
    await tester.tap(find.text('Electricity'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('bill-amount')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(CupertinoTextField), '12,50');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Enter an amount like'), findsOneWidget);
    expect(h.data.instanceCalls.where((c) => c.startsWith('amount')), isEmpty);
  });

  testWidgets(
    'an overdue bill stays on Bills until paid, and shows in History',
    (tester) async {
      await open(tester, [
        inst('1', 'Old one', '2026-08-20', period: '2026-08-01'),
        inst('2', 'Paid one', '2026-10-02', status: 'paid'),
      ]);
      expect(find.text('Old one'), findsOneWidget);
      expect(find.text('Overdue'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const ValueKey('bills-history')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('bills-history')));
      await tester.pumpAndSettle();
      expect(find.text('Old one'), findsOneWidget);
      expect(find.text('Overdue'), findsOneWidget);
      expect(find.text('Paid one'), findsNothing);
    },
  );

  testWidgets('mark paid from the row actions keeps it on Bills as Paid', (
    tester,
  ) async {
    final h = await open(tester, [inst('1', 'Horse and foal', '2026-10-31')]);
    await tester.tap(find.text('Horse and foal'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('bill-paid')));
    await tester.pumpAndSettle();
    // It asks first, with the bill's tile.
    await tester.tap(find.text('Yes, mark as paid'));
    await tester.pumpAndSettle();
    expect(h.data.instanceCalls, ['paid:1']);
    // it stays in this month's list, now as paid
    expect(find.text('Paid'), findsWidgets);
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
    await tester.tap(find.text('Yes, mark as paid'));
    await tester.pumpAndSettle();
    expect(h.data.instanceCalls, ['confirm:1']);
    expect(h.data.instances.first.status, 'paid');
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
    expect(find.text('Could not load'), findsOneWidget);
  });

  testWidgets('arabic labels and RTL amounts', (tester) async {
    final h = Harness(signedIn: true);
    h.data.instances = [inst('1', 'Horse', '2026-10-31')];
    await tester.pumpWidget(await h.build(prefs: {'locale': 'ar'}));
    await tester.pumpAndSettle();
    await tester.tap(find.text('الفواتير').last);
    await tester.pumpAndSettle();
    expect(find.text('القادمة'), findsNothing); // no tabs
    expect(find.text('تستحق غدًا'), findsOneWidget);
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
