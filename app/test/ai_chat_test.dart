import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/core/models.dart';

import 'support/fakes.dart';

Txn spend(String id, int halalas, {String? cat}) => Txn(
  id: id,
  type: 'purchase',
  direction: 'out',
  amountHalalas: halalas,
  occurredAt: DateTime.utc(2026, 10, 20, 9),
  merchant: 'ACME',
  merchantNorm: 'acme',
  categoryId: cat,
);

Future<Harness> openInsights(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final h = Harness(signedIn: true);
  h.data.aiOn = true;
  h.data.saved = ['Cut dining: ⃁ 900 is 20% over its average.'];
  h.data.history = [spend('1', 90000, cat: 'c-din')];
  h.data.txns = h.data.history;
  await tester.pumpWidget(await h.build());
  await tester.pumpAndSettle();
  await tester.tap(find.text('Insights').last);
  await tester.pumpAndSettle();
  return h;
}

void main() {
  testWidgets('the tips card opens the chat, from the button and the card', (
    tester,
  ) async {
    await openInsights(tester);
    expect(find.textContaining('Cut dining'), findsOneWidget);
    await tester.tap(find.text('Ask a question'));
    await tester.pumpAndSettle();
    expect(find.text('Ask about your spending'), findsOneWidget);
    expect(find.text('Where can I cut spending?'), findsOneWidget);
    expect(find.text('Why is Dining so high?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('nav-back')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('AI tips'));
    await tester.pumpAndSettle();
    expect(find.text('Ask about your spending'), findsOneWidget);
  });

  testWidgets(
    'a question sends only totals and the conversation, and shows the answer',
    (tester) async {
      final h = await openInsights(tester);
      await tester.tap(find.text('Ask a question'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Why is Dining so high?'));
      await tester.pumpAndSettle();
      expect(h.data.chatCalls, hasLength(1));
      final (agg, turns) = h.data.chatCalls.single;
      expect(agg['categories'], isNotEmpty);
      expect(agg.toString(), isNot(contains('ACME')));
      expect(turns, [
        {'role': 'user', 'content': 'Why is Dining so high?'},
      ]);
      expect(find.text('Dining is 900.00 SAR.'), findsOneWidget);

      await tester.enterText(
        find.byType(CupertinoTextField),
        'and my budgets?',
      );
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Send'));
      await tester.pumpAndSettle();
      expect(h.data.chatCalls, hasLength(2));
      expect(h.data.chatCalls.last.$2.map((t) => t['role']).toList(), [
        'user',
        'assistant',
        'user',
      ]);
      expect(find.text('and my budgets?'), findsOneWidget);
    },
  );

  testWidgets('a failed answer says why and Try again asks once more', (
    tester,
  ) async {
    final h = await openInsights(tester);
    h.data.chatResult = const AiOutcome.fail('cap_reached');
    await tester.tap(find.text('Ask a question'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Where can I cut spending?'));
    await tester.pumpAndSettle();
    expect(find.textContaining('AI budget is used up'), findsOneWidget);
    h.data.chatResult = const AiOutcome.ok(reply: 'Trim dining.');
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(h.data.chatCalls, hasLength(2));
    expect(h.data.chatCalls.last.$2, hasLength(1));
    expect(find.text('Trim dining.'), findsOneWidget);
    expect(find.textContaining('AI budget is used up'), findsNothing);
  });

  testWidgets('the send button is off for an empty box', (tester) async {
    final h = await openInsights(tester);
    await tester.tap(find.text('Ask a question'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Send'));
    await tester.pumpAndSettle();
    expect(h.data.chatCalls, isEmpty);
  });

  for (final lang in ['en', 'ar']) {
    testWidgets('the chat survives 2x text on a 360pt phone ($lang)', (
      tester,
    ) async {
      final h = Harness(signedIn: true);
      h.data.aiOn = true;
      h.data.saved = ['x ⃁ 1'];
      h.data.history = [spend('1', 90000, cat: 'c-din')];
      h.data.txns = h.data.history;
      tester.view.physicalSize = const Size(720, 1280);
      tester.view.devicePixelRatio = 2;
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(() {
        tester.view.reset();
        tester.platformDispatcher.clearAllTestValues();
      });
      await tester.pumpWidget(await h.build(prefs: {'locale': lang}));
      await tester.pumpAndSettle();
      await tester.tap(find.text(lang == 'en' ? 'Insights' : 'التحليلات').last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final ask = find.text(lang == 'en' ? 'Ask a question' : 'اطرح سؤالًا');
      await Scrollable.ensureVisible(tester.element(ask), alignment: 0.3);
      await tester.pumpAndSettle();
      await tester.tap(ask);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
