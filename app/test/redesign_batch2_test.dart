import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/core/models.dart';
import 'package:spending_tracker/ui/note_limit.dart';

import 'support/fakes.dart';

Txn _tx(
  String id,
  String merchant, {
  String? cat,
  String? card,
  String? account,
  String? note,
}) => Txn(
  id: id,
  type: 'purchase',
  direction: 'out',
  amountHalalas: 1800,
  occurredAt: DateTime.utc(2026, 10, 30, 9),
  merchant: merchant,
  merchantNorm: merchant.toLowerCase(),
  categoryId: cat,
  bank: 'alinma',
  accountLast4: account,
  cardLast4: card,
  note: note,
  source: 'sms',
);

Future<Harness> _activity(WidgetTester t, Harness h) async {
  t.view.physicalSize = const Size(800, 2400);
  t.view.devicePixelRatio = 2;
  addTearDown(t.view.reset);
  await t.pumpWidget(await h.build());
  await t.pumpAndSettle();
  await t.tap(find.text('Activity').last);
  await t.pumpAndSettle();
  return h;
}

void main() {
  group('date ranges (Riyadh, UTC+3)', () {
    test('last month in January is December', () {
      final r = const TxFilter(period: TxPeriod.lastMonth)
          .range(DateTime.utc(2027, 1, 15));
      expect(r!.$1, DateTime.utc(2026, 11, 30, 21)); // 1 Dec 00:00 Riyadh
      expect(r.$2, DateTime.utc(2026, 12, 31, 21)); // 1 Jan 00:00 Riyadh
    });

    test('late evening UTC already counts as the next Riyadh month', () {
      final r = const TxFilter().range(DateTime.utc(2027, 1, 31, 22));
      expect(r!.$1, DateTime.utc(2027, 1, 31, 21)); // 1 Feb Riyadh
    });

    test('a custom range includes its last day', () {
      final r = TxFilter(
        period: TxPeriod.custom,
        from: DateTime(2026, 2, 1),
        to: DateTime(2026, 2, 28),
      ).range(DateTime.utc(2026, 3, 5));
      expect(r!.$2, DateTime.utc(2026, 2, 28, 21)); // 1 Mar 00:00 Riyadh
    });
  });

  testWidgets('the card chip finds purchases stored with the card digits', (
    t,
  ) async {
    final h = Harness(signedIn: true)
      ..data.accounts = [
        const OwnAccount(
          id: 'c1',
          bank: 'alinma',
          last4: '7705',
          kind: 'credit_card',
        ),
      ]
      ..data.txns = [
        _tx('1', 'Card shop', card: '7705', account: '1111'),
        _tx('2', 'Other shop', account: '2222'),
      ];
    await _activity(t, h);
    await t.tap(find.text('All banks'));
    await t.pumpAndSettle();
    await t.tap(find.text('•••• 7705'));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('filter-show')));
    await t.pumpAndSettle();
    expect(find.text('Card shop'), findsOneWidget);
    expect(find.text('Other shop'), findsNothing);
  });

  testWidgets(
    'a category changed on the page shows there even when the row leaves the list',
    (t) async {
      final h = Harness(signedIn: true)
        ..data.txns = [_tx('1', 'OTTEN'), _tx('2', 'XYZ', cat: 'c-gro')];
      await _activity(t, h);
      await t.tap(
        find.textContaining('No category'),
      ); // only uncategorised rows
      await t.pumpAndSettle();
      await t.tap(find.text('OTTEN'));
      await t.pumpAndSettle();
      expect(find.text('No category'), findsOneWidget);
      await t.tap(find.text('Change category'));
      await t.pumpAndSettle();
      await t.tap(find.text('Dining'));
      await t.pumpAndSettle();
      expect(find.text('Dining'), findsOneWidget);
      expect(find.text('No category'), findsNothing);
    },
  );

  testWidgets('a note is saved when the page is left and shows on reopen', (
    t,
  ) async {
    final h = Harness(signedIn: true)..data.txns = [_tx('1', 'OTTEN')];
    await _activity(t, h);
    await t.tap(find.text('OTTEN'));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const ValueKey('txn-note')), 'Team lunch');
    await t.tap(find.byKey(const ValueKey('nav-back')));
    await t.pumpAndSettle();
    expect(h.data.notes['1'], 'Team lunch');
    await t.tap(find.text('OTTEN'));
    await t.pumpAndSettle();
    expect(find.text('Team lunch'), findsOneWidget);
  });

  for (final lang in ['en', 'ar']) {
    testWidgets('the transaction page survives 2x text ($lang)', (t) async {
      t.view.physicalSize = const Size(720, 1600);
      t.view.devicePixelRatio = 2;
      t.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(t.view.reset);
      addTearDown(t.platformDispatcher.clearAllTestValues);
      final h = Harness(signedIn: true)
        ..data.txns = [_tx('1', 'OTTEN', card: '7705')];
      await t.pumpWidget(await h.build(prefs: {'locale': lang}));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('tab-item-1')));
      await t.pumpAndSettle();
      await t.tap(find.text('OTTEN'));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      await t.scrollUntilVisible(
        find.byKey(const ValueKey('txn-delete')),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      expect(
        t.takeException(),
        isNull,
      ); // the bottom row wraps instead of overflowing
    });
  }

  test('a note stops at 500 characters as the database counts them', () {
    const limit = NoteLimit(5);
    final ok = limit.formatEditUpdate(
      TextEditingValue.empty,
      const TextEditingValue(text: '😀😀😀😀😀'),
    );
    expect(ok.text.runes.length, 5);
    final over = limit.formatEditUpdate(
      ok,
      const TextEditingValue(text: '😀😀😀😀😀😀'),
    );
    expect(over.text, ok.text);
  });
}
