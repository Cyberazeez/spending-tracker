import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/core/models.dart';

import 'support/fakes.dart';

// The harness clock is 2026-10-30 12:00 UTC (15:00 Riyadh).
Txn tx(
  String id,
  String utc,
  int halalas, {
  String merchant = 'Shop',
  String? cat,
  String direction = 'out',
  String type = 'purchase',
  bool internal = false,
}) => Txn(
  id: id,
  type: type,
  direction: direction,
  amountHalalas: halalas,
  occurredAt: DateTime.parse('${utc}Z'),
  merchant: merchant,
  merchantNorm: merchant.toLowerCase(),
  categoryId: cat,
  isInternal: internal,
  excludedFromSpend: internal,
);

Future<void> open(WidgetTester tester, Harness h, {String? locale}) async {
  await tester.pumpWidget(
    await h.build(prefs: {'locale': ?locale}),
  );
  await tester.pumpAndSettle();
  await tester.tap(
    find.text(locale == 'ar' ? 'العمليات' : 'Transactions').last,
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('rows are grouped by day with Today, Yesterday and a day total', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = Harness(signedIn: true)
      ..data.txns = [
        tx('1', '2026-10-30T10:00:00', 1950, cat: 'c-gro', merchant: 'Lulu'),
        tx('2', '2026-10-30T09:00:00', 2159, cat: 'c-din', merchant: 'Otten'),
        tx('3', '2026-10-29T10:00:00', 42999, merchant: 'Apple'),
        tx('4', '2026-10-25T10:00:00', 100, merchant: 'Old'),
      ];
    await open(tester, h);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Yesterday'), findsOneWidget);
    expect(find.textContaining(RegExp(r'Sun .*25 Oct')), findsOneWidget);
    expect(find.text('SAR 41.09'), findsOneWidget); // 19.50 + 21.59
    expect(find.text('SAR 429.99'), findsOneWidget);
  });

  testWidgets(
    'an uncategorised row is marked with "?" and asks for a category',
    (tester) async {
      final h = Harness(signedIn: true)
        ..data.txns = [tx('1', '2026-10-30T10:00:00', 1000, merchant: 'XYZ')];
      await open(tester, h);
      expect(find.text('?'), findsOneWidget);
      expect(find.textContaining('Choose category'), findsOneWidget);
    },
  );

  testWidgets('quick filter chips drive the same filter as the sheet', (
    tester,
  ) async {
    final h = Harness(signedIn: true)
      ..data.txns = [
        tx('1', '2026-10-30T10:00:00', 1000, cat: 'c-din', merchant: 'Otten'),
        tx('2', '2026-10-30T10:01:00', 500, merchant: 'XYZ'),
      ];
    await open(tester, h);
    await tester.tap(find.text('No category'));
    await tester.pumpAndSettle();
    expect(h.data.lastFilter.uncategorizedOnly, isTrue);
    expect(find.text('Otten'), findsNothing);
    await tester.tap(find.text('Hide internal'));
    await tester.pumpAndSettle();
    expect(h.data.lastFilter.hideInternal, isTrue);
    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();
    expect(h.data.lastFilter.uncategorizedOnly, isFalse);
    expect(h.data.lastFilter.hideInternal, isFalse);
    expect(find.text('Otten'), findsOneWidget);
  });

  testWidgets(
    'internal moves are listed but dimmed and never counted in the day',
    (tester) async {
      final h = Harness(signedIn: true)
        ..data.txns = [
          tx('1', '2026-10-30T10:00:00', 1000, cat: 'c-din', merchant: 'Otten'),
          tx(
            '2',
            '2026-10-30T10:01:00',
            5000,
            merchant: 'barq',
            type: 'wallet_topup',
            internal: true,
          ),
        ];
      await open(tester, h);
      expect(find.text('barq'), findsOneWidget);
      expect(
        find.text('SAR 10.00'),
        findsOneWidget,
      ); // the day total is only Otten
      expect(find.textContaining('Internal'), findsOneWidget);
    },
  );

  for (final lang in ['en', 'ar']) {
    testWidgets('the list survives 2x text on a 360pt phone ($lang)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(720, 1280);
      tester.view.devicePixelRatio = 2;
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(() {
        tester.view.reset();
        tester.platformDispatcher.clearAllTestValues();
      });
      final h = Harness(signedIn: true)
        ..data.txns = [
          tx(
            '1',
            '2026-10-30T10:00:00',
            123456789,
            cat: 'c-din',
            merchant: 'A very long merchant name that keeps going and going',
          ),
          tx('2', '2026-10-30T09:00:00', 999999, merchant: 'No category here'),
          tx(
            '3',
            '2026-10-29T09:00:00',
            50000,
            direction: 'in',
            type: 'salary',
            merchant: 'Salary',
          ),
        ];
      await open(tester, h, locale: lang);
      expect(tester.takeException(), isNull);
    });
  }
}
