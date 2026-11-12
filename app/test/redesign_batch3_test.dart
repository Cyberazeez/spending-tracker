import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/core/models.dart';

import 'support/fakes.dart';

ObligationInstance _inst({String kind = 'bill', String status = 'pending'}) =>
    ObligationInstance(
      id: '1',
      obligationId: 'o-1',
      name: 'Electricity',
      kind: kind,
      periodStart: DateTime.utc(2026, 10),
      dueDate: DateTime.utc(2026, 10, 31),
      status: status,
      expectedHalalas: 38500,
    );

Future<Harness> _bills(WidgetTester t, List<ObligationInstance> list) async {
  t.view.physicalSize = const Size(800, 2400);
  t.view.devicePixelRatio = 2;
  addTearDown(t.view.reset);
  final h = Harness(signedIn: true)..data.instances = list;
  await t.pumpWidget(await h.build());
  await t.pumpAndSettle();
  await t.tap(find.text('Bills').last);
  await t.pumpAndSettle();
  return h;
}

void main() {
  testWidgets(
    '+ shows the three starting points; Bill opens the form as a bill',
    (t) async {
      await _bills(t, const []);
      await t.tap(find.bySemanticsLabel('Add an obligation'));
      await t.pumpAndSettle();
      expect(find.text('Add a bill'), findsOneWidget);
      for (final k in ['bill', 'fixed', 'loan']) {
        expect(find.byKey(ValueKey('add-bill-$k')), findsOneWidget);
      }
      // Card statements are not tracked on Bills (owner, 2026-11-12).
      expect(find.byKey(const ValueKey('add-bill-card')), findsNothing);
      await t.tap(find.byKey(const ValueKey('add-bill-bill')));
      await t.pumpAndSettle();
      expect(find.text('New obligation'), findsOneWidget);
      // The bill is chosen and its amount is estimated.
      expect(
        find.text(
          'Optional for a bill: leave it empty and the bill message sets each month\'s amount.',
        ),
        findsOneWidget,
      );
    },
  );

  for (final lang in ['en', 'ar']) {
    testWidgets('Add a bill survives 2x text at 360 wide ($lang)', (t) async {
      t.view.physicalSize = const Size(720, 1600);
      t.view.devicePixelRatio = 2;
      t.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(t.view.reset);
      addTearDown(t.platformDispatcher.clearAllTestValues);
      final h = Harness(signedIn: true);
      await t.pumpWidget(await h.build(prefs: {'locale': lang}));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('tab-item-2')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('obligations-add')));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('add-bill-loan')), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('an old card statement from the server is not shown', (t) async {
    await _bills(t, [
      _inst(),
      ObligationInstance(
        id: 'st',
        obligationId: 'o-st',
        name: 'Credit card 8119 statement',
        kind: 'card_statement',
        periodStart: DateTime.utc(2026, 10),
        dueDate: DateTime.utc(2026, 10, 25),
        status: 'paid',
        expectedHalalas: 846323,
        actualHalalas: 846323,
      ),
    ]);
    expect(find.text('Electricity'), findsWidgets);
    expect(find.textContaining('statement'), findsNothing);
    expect(find.textContaining('8,463.23'), findsNothing);
  });

  testWidgets('the bill sheet saves a changed setting at once', (t) async {
    final h = await _bills(t, [_inst()]);
    h.data.editing = const ObligationDef(
      id: 'o-1',
      name: 'Electricity',
      kind: 'bill',
      amountHalalas: 38500,
      day: 6,
      leadDays: 3,
    );
    await t.tap(find.text('Electricity'));
    await t.pumpAndSettle();
    expect(find.text('3 days before'), findsOneWidget);
    await t.tap(find.text('Estimated'));
    await t.pumpAndSettle();
    final (id, d) = h.data.savedObligations.single;
    expect(id, 'o-1');
    expect(d.amountType, 'estimated');
    expect(d.leadDays, 3);
    expect(d.day, 6);
  });

  testWidgets('Mark as paid asks with the bill tile; Cancel changes nothing', (
    t,
  ) async {
    final h = await _bills(t, [_inst()]);
    await t.tap(find.text('Electricity'));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('bill-paid')));
    await t.pumpAndSettle();
    expect(find.text('Mark Electricity as paid?'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('confirm-no')));
    await t.pumpAndSettle();
    expect(h.data.instanceCalls, isEmpty);
  });

  testWidgets('a suggested payment: "Not this payment" rejects it', (t) async {
    final h = await _bills(t, [
      ObligationInstance(
        id: '1',
        obligationId: 'o-1',
        name: 'Internet',
        kind: 'bill',
        periodStart: DateTime.utc(2026, 10),
        dueDate: DateTime.utc(2026, 10, 31),
        status: 'pending',
        matchState: 'suggested',
        expectedHalalas: 29000,
        actualHalalas: 29000,
        transactionId: 't-9',
      ),
    ]);
    await t.tap(find.text('Confirm'));
    await t.pumpAndSettle();
    expect(find.textContaining('looks like this bill'), findsOneWidget);
    await t.tap(find.text('Not this payment'));
    await t.pumpAndSettle();
    expect(h.data.instanceCalls, ['reject:1']);
  });

  testWidgets('Skip this month skips it and closes the sheet', (t) async {
    final h = await _bills(t, [_inst()]);
    await t.tap(find.text('Electricity'));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('bill-skip')));
    await t.pumpAndSettle();
    expect(h.data.instanceCalls, ['skipped:1']);
    expect(find.byKey(const ValueKey('bill-skip')), findsNothing);
  });

  for (final lang in ['en', 'ar']) {
    testWidgets('the bill sheet survives 2x text at 360 wide ($lang)', (
      t,
    ) async {
      // 360 pt wide; tall enough that the row is not under the floating tab bar.
      t.view.physicalSize = const Size(720, 2000);
      t.view.devicePixelRatio = 2;
      t.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(t.view.reset);
      addTearDown(t.platformDispatcher.clearAllTestValues);
      final h = Harness(signedIn: true)..data.instances = [_inst()];
      await t.pumpWidget(await h.build(prefs: {'locale': lang}));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('tab-item-2')));
      await t.pumpAndSettle();
      await t.tap(find.text('Electricity').first);
      await t.pumpAndSettle();
      // The sheet really opened (the header with the status pill is laid out).
      expect(find.byKey(const ValueKey('bill-amount')), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('a second tap on Skip while the first runs sends nothing more', (
    t,
  ) async {
    final h = await _bills(t, [_inst()]);
    h.data.instanceDelay = const Duration(milliseconds: 300);
    await t.tap(find.text('Electricity'));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('bill-skip')));
    await t.pump(const Duration(milliseconds: 60));
    await t.tap(find.byKey(const ValueKey('bill-skip')), warnIfMissed: false);
    await t.pumpAndSettle();
    expect(h.data.instanceCalls, ['skipped:1']);
    expect(t.takeException(), isNull);
    // Only the sheet closed: the Bills tab is still there.
    expect(find.byKey(const ValueKey('tab-pill')), findsOneWidget);
  });

  testWidgets(
    'closing the sheet while an action runs still refreshes the list',
    (t) async {
      final h = await _bills(t, [_inst()]);
      h.data.instanceDelay = const Duration(seconds: 2);
      await t.tap(find.text('Electricity'));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('bill-skip')));
      await t.pump(const Duration(milliseconds: 50));
      await t.tapAt(const Offset(200, 40)); // the dimmed area above the sheet
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('bill-skip')), findsNothing);
      await t.pump(const Duration(seconds: 3));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(find.byKey(const ValueKey('tab-pill')), findsOneWidget);
      // The list was refreshed: the bill left the pending list.
      expect(find.text('Electricity'), findsNothing);
    },
  );

  testWidgets('a stopped bill opened from History shows no settings', (
    t,
  ) async {
    final h = Harness(signedIn: true)
      ..data.instances = [_inst(status: 'paid')]
      ..data.editing = const ObligationDef(
        id: 'o-1',
        name: 'Electricity',
        amountHalalas: 38500,
        active: false,
      );
    t.view.physicalSize = const Size(800, 2400);
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);
    await t.pumpWidget(await h.build());
    await t.pumpAndSettle();
    await t.tap(find.text('Bills').last);
    await t.pumpAndSettle();
    await t.tap(find.text('Electricity').first);
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('bill-reopen')), findsOneWidget);
    for (final k in ['bill-repeats', 'bill-day', 'bill-remind', 'bill-stop']) {
      expect(find.byKey(ValueKey(k)), findsNothing);
    }
    expect(find.text('Active'), findsNothing);
  });

  testWidgets('changing the due day saves it and closes the sheet', (t) async {
    final h = await _bills(t, [_inst()]);
    await t.tap(find.text('Electricity'));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('bill-day')));
    await t.pumpAndSettle();
    await t.drag(find.byType(CupertinoPicker), const Offset(0, -80));
    await t.pumpAndSettle();
    await t.tap(find.text('Done').last);
    await t.pumpAndSettle();
    expect(h.data.savedObligations, hasLength(1));
    expect(find.byKey(const ValueKey('bill-day')), findsNothing);
  });
}
