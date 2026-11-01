import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/core/models.dart';

import 'support/fakes.dart';

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

Harness loaded() => Harness(signedIn: true)
  ..data.txns = [
    tx(
      '1',
      '2026-10-05T09:00:00',
      90000,
      cat: 'c-din',
      merchant: 'A very long merchant name that keeps going and going',
    ),
    tx('2', '2026-10-06T09:00:00', 30000, merchant: 'Lulu'),
  ]
  ..data.history = [
    tx('1', '2026-10-05T09:00:00', 90000, cat: 'c-din', merchant: 'Otten'),
    tx('2', '2026-10-06T09:00:00', 30000, cat: 'c-gro', merchant: 'Lulu'),
  ]
  ..data.budgetList = [
    const Budget(id: 'b', categoryId: 'c-din', limitHalalas: 100000),
  ]
  ..data.instances = [
    ObligationInstance(
      id: 'i1',
      obligationId: 'o1',
      name: 'Credit card 8119 statement with a long name',
      kind: 'card_statement',
      dueDate: DateTime.utc(2026, 11, 25),
      status: 'pending',
      expectedHalalas: 846323,
    ),
  ]
  ..data.gaps = [
    SenderGap(sender: 'alinma', lastReceivedAt: DateTime.utc(2026, 10, 24, 8)),
  ];

const tabsEn = ['Home', 'Transactions', 'Obligations', 'Insights', 'More'];
const tabsAr = ['الرئيسية', 'العمليات', 'الالتزامات', 'التحليلات', 'المزيد'];

void main() {
  for (final lang in ['en', 'ar']) {
    for (final dark in [false, true]) {
      testWidgets(
        'every tab renders on a small phone with 2x text ($lang${dark ? ', dark' : ''})',
        (tester) async {
          tester.view.physicalSize = const Size(720, 1280); // 360 x 640 logical
          tester.view.devicePixelRatio = 2;
          tester.platformDispatcher.textScaleFactorTestValue = 2.0;
          tester.platformDispatcher.platformBrightnessTestValue = dark
              ? Brightness.dark
              : Brightness.light;
          addTearDown(() {
            tester.view.reset();
            tester.platformDispatcher.clearAllTestValues();
          });
          await tester.pumpWidget(
            await loaded().build(prefs: {'locale': lang}),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: 'home');
          for (final label in (lang == 'en' ? tabsEn : tabsAr).skip(1)) {
            await tester.tap(find.text(label).last);
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull, reason: label);
          }
        },
      );
    }
  }

  testWidgets('icon-only buttons have spoken labels', (tester) async {
    await tester.pumpWidget(await loaded().build());
    await tester.pumpAndSettle();
    final handle = tester.ensureSemantics();
    expect(find.bySemanticsLabel('Add a transaction'), findsOneWidget);
    handle.dispose();
  });
}
