import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/core/models.dart';

import 'support/fakes.dart';

Txn tx(String id, String merchant, {String? categoryId}) => Txn(
  id: id,
  type: 'purchase',
  direction: 'out',
  amountHalalas: 1900,
  occurredAt: DateTime.utc(2026, 10, 30, 11, 5),
  merchant: merchant,
  merchantNorm: merchant.toLowerCase(),
  categoryId: categoryId,
);

Future<void> open(WidgetTester tester, Harness h) async {
  await tester.pumpWidget(await h.build());
  await tester.pumpAndSettle();
  await tester.tap(find.text('Transactions').last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the category, or "No category" in orange', (tester) async {
    final h = Harness(signedIn: true)
      ..data.txns = [tx('1', 'OTTEN', categoryId: 'c-din'), tx('2', 'XYZ')];
    await open(tester, h);
    expect(find.textContaining('Dining'), findsOneWidget);
    expect(find.textContaining('No category'), findsOneWidget);
  });

  testWidgets('search narrows the list', (tester) async {
    final h = Harness(signedIn: true)
      ..data.txns = [tx('1', 'OTTEN'), tx('2', 'LULU')];
    await open(tester, h);
    await tester.enterText(find.byType(CupertinoSearchTextField), 'lulu');
    await tester.pumpAndSettle();
    expect(find.text('LULU'), findsOneWidget);
    expect(find.text('OTTEN'), findsNothing);
    expect(h.data.lastFilter.query, 'lulu');
  });

  testWidgets('uncategorized filter hides categorized rows', (tester) async {
    final h = Harness(signedIn: true)
      ..data.txns = [tx('1', 'OTTEN', categoryId: 'c-din'), tx('2', 'XYZ')];
    await open(tester, h);
    await tester.tap(
      find.byIcon(CupertinoIcons.line_horizontal_3_decrease_circle),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Uncategorized only'));
    await tester.pumpAndSettle();
    expect(find.text('XYZ'), findsOneWidget);
    expect(find.text('OTTEN'), findsNothing);
  });

  testWidgets('recategorizing asks about past ones and remembers the rule', (
    tester,
  ) async {
    final h = Harness(signedIn: true)
      ..data.txns = [tx('1', 'OTTEN'), tx('2', 'OTTEN')];
    await open(tester, h);
    await tester.tap(find.text('OTTEN').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dining'));
    await tester.pumpAndSettle();
    expect(find.textContaining('1 other'), findsOneWidget);
    await tester.tap(find.text('Change all'));
    await tester.pumpAndSettle();
    expect(h.data.categoryCalls, [('1', 'c-din', 'otten', true)]);
    expect(find.textContaining('No category'), findsNothing);
  });

  testWidgets('"Only future ones" keeps the past as it is', (tester) async {
    final h = Harness(signedIn: true)
      ..data.txns = [tx('1', 'OTTEN'), tx('2', 'OTTEN')];
    await open(tester, h);
    await tester.tap(find.text('OTTEN').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dining'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Only future ones'));
    await tester.pumpAndSettle();
    expect(h.data.categoryCalls, [('1', 'c-din', 'otten', false)]);
    expect(find.textContaining('No category'), findsOneWidget);
  });
}
