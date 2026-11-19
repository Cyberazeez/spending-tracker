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

Future<void> openTips(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('ai-tips-row')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'Get tips opens the chat with the saved tips as the first answer',
    (tester) async {
      final h = await openInsights(tester);
      expect(find.text('Get tips'), findsOneWidget);
      // The tips themselves are no longer on Insights.
      expect(find.textContaining('Cut dining'), findsNothing);
      await openTips(tester);
      expect(find.text('Ask about your spending'), findsOneWidget);
      expect(find.text('Give me savings tips for this month'), findsOneWidget);
      expect(find.textContaining('1. Cut dining'), findsOneWidget);
      expect(find.textContaining('Tips for '), findsOneWidget);
      expect(
        find.text('Based on totals only. Check the numbers before acting.'),
        findsOneWidget,
      );
      expect(h.data.tipCalls, isEmpty, reason: 'saved tips need no AI call');
      expect(find.text('New tips'), findsOneWidget);
      expect(find.text('Why is Dining so high?'), findsOneWidget);
    },
  );

  testWidgets(
    'with no saved tips, the chat asks for them; New tips asks again',
    (tester) async {
      final h = await openInsights(tester);
      h.data.saved = [];
      await openTips(tester);
      expect(h.data.tipCalls, hasLength(1));
      expect(h.data.tipCalls.single.$1.toString(), isNot(contains('ACME')));
      expect(find.textContaining('1. '), findsOneWidget);
      await tester.tap(find.text('New tips'));
      await tester.pumpAndSettle();
      expect(h.data.tipCalls, hasLength(2));
    },
  );

  testWidgets('failed tips say why and Try again asks for tips again', (
    tester,
  ) async {
    final h = await openInsights(tester);
    h.data.saved = [];
    final ok = h.data.tipsResult;
    h.data.tipsResult = const AiOutcome.fail('cap_reached');
    await openTips(tester);
    expect(find.textContaining('AI budget is used up'), findsOneWidget);
    h.data.tipsResult = ok;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(h.data.tipCalls, hasLength(2));
    expect(h.data.chatCalls, isEmpty);
    expect(find.text('Give me savings tips for this month'), findsOneWidget);
    expect(find.textContaining('AI budget is used up'), findsNothing);
  });

  testWidgets(
    'a follow-up sends only totals and the conversation, tips included',
    (tester) async {
      final h = await openInsights(tester);
      await openTips(tester);
      await tester.tap(find.text('Why is Dining so high?'));
      await tester.pumpAndSettle();
      expect(h.data.chatCalls, hasLength(1));
      final (agg, turns) = h.data.chatCalls.single;
      expect(agg['categories'], isNotEmpty);
      expect(agg.toString(), isNot(contains('ACME')));
      expect(turns.map((t) => t['role']).toList(), [
        'user',
        'assistant',
        'user',
      ]);
      expect(turns.first['content'], 'Give me savings tips for this month');
      expect(turns[1]['content'], contains('1. Cut dining'));
      expect(turns[1]['content'], isNot(contains('Based on totals')));
      expect(turns.last['content'], 'Why is Dining so high?');
      expect(find.text('Dining is 900.00 SAR.'), findsOneWidget);

      await tester.enterText(
        find.byType(CupertinoTextField),
        'and my budgets?',
      );
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Send'));
      await tester.pumpAndSettle();
      expect(h.data.chatCalls, hasLength(2));
      expect(h.data.chatCalls.last.$2, hasLength(5));
      expect(find.text('and my budgets?'), findsOneWidget);
    },
  );

  testWidgets('a failed answer says why and Try again asks once more', (
    tester,
  ) async {
    final h = await openInsights(tester);
    h.data.chatResult = const AiOutcome.fail('cap_reached');
    await openTips(tester);
    await tester.tap(find.text('Where can I cut spending?'));
    await tester.pumpAndSettle();
    expect(find.textContaining('AI budget is used up'), findsOneWidget);
    h.data.chatResult = const AiOutcome.ok(reply: 'Trim dining.');
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(h.data.chatCalls, hasLength(2));
    expect(h.data.chatCalls.last.$2, hasLength(3));
    expect(h.data.tipCalls, isEmpty);
    expect(find.text('Trim dining.'), findsOneWidget);
    expect(find.textContaining('AI budget is used up'), findsNothing);
  });

  testWidgets('the send button is off for an empty box', (tester) async {
    final h = await openInsights(tester);
    await openTips(tester);
    await tester.tap(find.bySemanticsLabel('Send'));
    await tester.pumpAndSettle();
    expect(h.data.chatCalls, isEmpty);
  });

  testWidgets('no Get tips row while AI is off', (tester) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final h = Harness(signedIn: true);
    h.data.history = [spend('1', 90000, cat: 'c-din')];
    h.data.txns = h.data.history;
    await tester.pumpWidget(await h.build());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Insights').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('ai-tips-row')), findsNothing);
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
      final ask = find.byKey(const ValueKey('ai-tips-row'));
      await Scrollable.ensureVisible(tester.element(ask), alignment: 0.3);
      await tester.pumpAndSettle();
      await tester.tap(ask);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
