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
    '+ shows the four starting points; Bill opens the form as a bill',
    (t) async {
      await _bills(t, const []);
      await t.tap(find.bySemanticsLabel('Add an obligation'));
      await t.pumpAndSettle();
      expect(find.text('Add a bill'), findsOneWidget);
      for (final k in ['bill', 'fixed', 'loan', 'card']) {
        expect(find.byKey(ValueKey('add-bill-$k')), findsOneWidget);
      }
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

  testWidgets(
    'the card statement tile starts a bill named after the statement',
    (t) async {
      await _bills(t, const []);
      await t.tap(find.bySemanticsLabel('Add an obligation'));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('add-bill-card')));
      await t.pumpAndSettle();
      expect(find.text('Card statement'), findsOneWidget); // in the name field
    },
  );

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
    testWidgets('the bill sheet survives 2x text ($lang)', (t) async {
      t.view.physicalSize = const Size(720, 1400);
      t.view.devicePixelRatio = 2;
      t.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(t.view.reset);
      addTearDown(t.platformDispatcher.clearAllTestValues);
      final h = Harness(signedIn: true)..data.instances = [_inst()];
      await t.pumpWidget(await h.build(prefs: {'locale': lang}));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('tab-item-2')));
      await t.pumpAndSettle();
      await t.tap(find.text('Electricity'));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    });
  }
}
