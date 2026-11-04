import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/core/models.dart';

import 'package:spending_tracker/ui/pill_tab_bar.dart';

import 'support/fakes.dart';

Txn tx(
  String id,
  String type,
  String dir,
  int h, {
  String? merchant,
  bool internal = false,
}) => Txn(
  id: id,
  type: type,
  direction: dir,
  amountHalalas: h,
  occurredAt: DateTime.utc(2026, 10, 30, 11, 5),
  merchant: merchant,
  isInternal: internal,
);

Future<void> openTransactions(WidgetTester tester, Harness h) async {
  await tester.pumpWidget(await h.build());
  await tester.pumpAndSettle();
  await tester.tap(find.text('Transactions').last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the last transaction can be scrolled clear of the tab bar', (
    tester,
  ) async {
    final h = Harness(signedIn: true);
    h.data.txns = [
      for (var i = 0; i < 40; i++)
        tx('t$i', 'purchase', 'out', 1000 + i, merchant: 'Shop $i'),
    ];
    await openTransactions(tester, h);
    await tester.fling(
      find.byType(Scrollable).first,
      const Offset(0, -6000),
      3000,
    );
    await tester.pumpAndSettle();
    final lastBottom = tester.getBottomLeft(find.text('Shop 39')).dy;
    final tabTop = tester.getTopLeft(find.byType(PillTabBar)).dy;
    expect(lastBottom, lessThanOrEqualTo(tabTop));
  });

  testWidgets('empty state offers quick add', (tester) async {
    final h = Harness(signedIn: true);
    await openTransactions(tester, h);
    expect(find.text('No transactions yet'), findsOneWidget);
    expect(find.widgetWithText(CupertinoButton, 'Quick add'), findsOneWidget);
  });

  testWidgets('list shows merchant, type, SAR amounts, signs and Riyadh time', (
    tester,
  ) async {
    final h = Harness(signedIn: true)
      ..data.txns = [
        tx('1', 'purchase', 'out', 1900, merchant: 'OTTEN'),
        tx('2', 'salary', 'in', 1382293),
        tx('3', 'wallet_topup', 'out', 100, merchant: 'barq', internal: true),
      ];
    await openTransactions(tester, h);
    expect(find.text('OTTEN'), findsOneWidget);
    expect(find.text('− SAR 19.00'), findsOneWidget);
    expect(find.text('+ SAR 13,822.93'), findsOneWidget);
    expect(find.textContaining('Internal'), findsOneWidget);
    expect(find.textContaining('14:05'), findsWidgets);
    expect(find.text('Today'), findsOneWidget); // grouped by day
  });

  testWidgets('a failed load shows an error with retry', (tester) async {
    final h = Harness(signedIn: true)..data.failLoad = true;
    await openTransactions(tester, h);
    expect(find.text('Could not load. Pull to retry.'), findsOneWidget);
    h.data.failLoad = false;
    h.data.txns = [tx('1', 'purchase', 'out', 500, merchant: 'Shop')];
    await tester.tap(find.widgetWithText(CupertinoButton, 'Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Shop'), findsOneWidget);
  });

  testWidgets(
    'quick add validates the amount, then saves and returns to the list',
    (tester) async {
      final h = Harness(signedIn: true);
      await openTransactions(tester, h);
      await tester.tap(find.widgetWithText(CupertinoButton, 'Quick add'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(CupertinoButton, 'Save'));
      await tester.pumpAndSettle();
      expect(find.text('Enter an amount like 25 or 25.50'), findsOneWidget);
      expect(h.data.added, isEmpty);

      await tester.enterText(
        find.widgetWithText(CupertinoTextField, 'Amount (SAR)'),
        '25.5',
      );
      await tester.enterText(
        find.widgetWithText(CupertinoTextField, 'Merchant or note'),
        'Coffee',
      );
      await tester.tap(find.widgetWithText(CupertinoButton, 'Save'));
      await tester.pumpAndSettle();
      expect(h.data.added.length, 1);
      expect(h.data.added.single.amountHalalas, 2550);
      expect(h.data.added.single.direction, 'out');
      expect(h.data.added.single.merchant, 'Coffee');
    },
  );

  testWidgets('quick add can record money received', (tester) async {
    final h = Harness(signedIn: true);
    await openTransactions(tester, h);
    await tester.tap(find.widgetWithText(CupertinoButton, 'Quick add'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Received'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(CupertinoTextField, 'Amount (SAR)'),
      '100',
    );
    await tester.tap(find.widgetWithText(CupertinoButton, 'Save'));
    await tester.pumpAndSettle();
    expect(h.data.added.single.direction, 'in');
  });

  group('needs review inbox', () {
    RawMessage raw(String id) => RawMessage(
      id: id,
      sender: 'SNB-AlAhli',
      body: 'دائن مدخرات\nمبلغ 944.96SAR',
      receivedAt: DateTime.utc(2026, 8, 30, 9, 50),
    );

    testWidgets('badge shows the count and opens the inbox', (tester) async {
      final h = Harness(signedIn: true)..data.review = [raw('r1'), raw('r2')];
      await openTransactions(tester, h);
      expect(find.text('2 to review'), findsOneWidget);
      await tester.tap(find.text('2 to review'));
      await tester.pumpAndSettle();
      expect(find.text('SNB-AlAhli'), findsNWidgets(2));
    });

    testWidgets('dismiss marks it as not a transaction', (tester) async {
      final h = Harness(signedIn: true)..data.review = [raw('r1')];
      await openTransactions(tester, h);
      await tester.tap(find.text('1 to review'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('SNB-AlAhli'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Not a transaction'));
      await tester.pumpAndSettle();
      expect(h.data.dismissed, ['r1']);
      expect(find.text('Nothing to review'), findsOneWidget);
    });

    testWidgets(
      'convert opens the form pre-filled with the SMS time and saves',
      (tester) async {
        final h = Harness(signedIn: true)..data.review = [raw('r1')];
        await openTransactions(tester, h);
        await tester.tap(find.text('1 to review'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('SNB-AlAhli'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Add as transaction'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.widgetWithText(CupertinoTextField, 'Amount (SAR)'),
          '944.96',
        );
        await tester.tap(find.widgetWithText(CupertinoButton, 'Save'));
        await tester.pumpAndSettle();
        expect(h.data.converted['r1']!.amountHalalas, 94496);
        expect(
          h.data.converted['r1']!.occurredAt,
          DateTime.utc(2026, 8, 30, 9, 50),
        );
      },
    );

    testWidgets('empty inbox says so', (tester) async {
      final h = Harness(signedIn: true);
      await tester.pumpWidget(await h.build());
      await tester.pumpAndSettle();
      await tester.tap(find.text('More'));
      await tester.pumpAndSettle();
      // no pending review rows: the badge is absent on the list
      await tester.tap(find.text('Transactions').last);
      await tester.pumpAndSettle();
      expect(find.textContaining('to review'), findsNothing);
    });
  });

  testWidgets('arabic: amounts read right-to-left with SAR after the number', (
    tester,
  ) async {
    final h = Harness(signedIn: true)
      ..data.txns = [tx('1', 'purchase', 'out', 1900, merchant: 'OTTEN')];
    await tester.pumpWidget(await h.build(prefs: {'locale': 'ar'}));
    await tester.pumpAndSettle();
    await tester.tap(find.text('العمليات').last);
    await tester.pumpAndSettle();
    expect(find.text('− 19.00 ر.س'), findsOneWidget);
    expect(find.textContaining('بدون فئة'), findsWidgets);
  });
}

DateTime h0() => DateTime.now().toUtc().subtract(const Duration(minutes: 5));
