import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/core/models.dart';

import 'support/fakes.dart';

void _tall(WidgetTester t) {
  t.view.physicalSize = const Size(800, 3000);
  t.view.devicePixelRatio = 2;
  addTearDown(t.view.reset);
}

Future<void> _openBudget(WidgetTester t, Harness h) async {
  await t.pumpWidget(await h.build());
  await t.pumpAndSettle();
  await t.tap(find.byKey(const ValueKey('tab-item-4')));
  await t.pumpAndSettle();
  await t.tap(find.text('Monthly budget'));
  await t.pumpAndSettle();
}

RawMessage _raw(String id, String status) => RawMessage(
  id: id,
  sender: 'alinma',
  body: 'Purchase 75.00 SAR card **4821 at [merchant] on 09/11',
  receivedAt: DateTime.utc(2026, 11, 9, 11, 20),
  parseStatus: status,
);

void main() {
  group('monthly budget sheet', () {
    testWidgets('one sheet: presets, the chosen one highlighted, Save', (
      t,
    ) async {
      _tall(t);
      final h = Harness(signedIn: true);
      await _openBudget(t, h);
      // No budget yet: no remove link.
      expect(find.byKey(const ValueKey('amount-remove')), findsNothing);
      for (final p in ['4,000', '5,000', '6,000', '8,000']) {
        expect(find.text(p), findsOneWidget);
      }
      await t.tap(find.text('6,000'));
      await t.pumpAndSettle();
      final chip = t.widget<Text>(find.text('6,000'));
      expect(
        chip.style!.color,
        isNot(t.widget<Text>(find.text('5,000')).style!.color),
      );
      await t.tap(find.byKey(const ValueKey('amount-save')));
      await t.pumpAndSettle();
      expect(h.data.monthlyBudget, 600000);
    });

    testWidgets('with a budget the same sheet removes it in one tap', (
      t,
    ) async {
      _tall(t);
      final h = Harness(signedIn: true)..data.monthlyBudget = 500000;
      await _openBudget(t, h);
      expect(find.text('Remove the budget'), findsOneWidget);
      await t.tap(find.text('Remove the budget'));
      await t.pumpAndSettle();
      expect(h.data.monthlyBudget, isNull);
    });

    testWidgets('saving the same amount sends nothing', (t) async {
      _tall(t);
      final h = Harness(signedIn: true)..data.monthlyBudget = 500000;
      await _openBudget(t, h);
      await t.tap(find.byKey(const ValueKey('amount-save')));
      await t.pumpAndSettle();
      expect(
        h.data.instanceCalls.where((c) => c.startsWith('monthlybudget')),
        isEmpty,
      );
    });

    for (final lang in ['en', 'ar']) {
      testWidgets('the budget sheet survives 2x text ($lang)', (t) async {
        t.view.physicalSize = const Size(720, 1600);
        t.view.devicePixelRatio = 2;
        t.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(t.view.reset);
        addTearDown(t.platformDispatcher.clearAllTestValues);
        final h = Harness(signedIn: true)..data.monthlyBudget = 600000;
        await t.pumpWidget(await h.build(prefs: {'locale': lang}));
        await t.pumpAndSettle();
        await t.tap(find.byKey(const ValueKey('tab-item-4')));
        await t.pumpAndSettle();
        await t.tap(
          find
              .text(lang == 'en' ? 'Monthly budget' : 'الميزانية الشهرية')
              .first,
        );
        await t.pumpAndSettle();
        expect(find.byKey(const ValueKey('amount-save')), findsOneWidget);
        expect(t.takeException(), isNull);
      });
    }
  });

  group('needs review', () {
    Future<Harness> openReview(WidgetTester t, Harness h) async {
      _tall(t);
      await t.pumpWidget(await h.build());
      await t.pumpAndSettle();
      await t.tap(find.text('Activity').last);
      await t.pumpAndSettle();
      await t.tap(find.textContaining('to review'));
      await t.pumpAndSettle();
      return h;
    }

    testWidgets('each message is a card with its bank, the SMS and why', (
      t,
    ) async {
      await openReview(
        t,
        Harness(signedIn: true)
          ..data.review = [
            _raw('a', 'needs_review'),
            _raw('b', 'low_confidence'),
            _raw('c', 'failed'),
          ],
      );
      expect(find.text('Could not read'), findsOneWidget);
      expect(find.text('Alinma Bank'), findsNWidgets(3));
      expect(find.textContaining('Purchase 75.00 SAR'), findsNWidgets(3));
      expect(find.text('New message format'), findsOneWidget);
      expect(find.text('Not sure'), findsOneWidget);
      expect(find.text('Could not read it'), findsOneWidget);
    });

    testWidgets('Not a purchase dismisses it in one tap', (t) async {
      final h = await openReview(
        t,
        Harness(signedIn: true)
          ..data.review = [_raw('a', 'needs_review'), _raw('b', 'failed')],
      );
      await t.tap(find.byKey(const ValueKey('review-dismiss-a')));
      await t.pumpAndSettle();
      expect(h.data.dismissed, ['a']);
      expect(find.byKey(const ValueKey('review-a')), findsNothing);
      expect(find.byKey(const ValueKey('review-b')), findsOneWidget);
    });
  });

  testWidgets('the chat keeps "Try asking" under the answers', (t) async {
    _tall(t);
    final h = Harness(signedIn: true)
      ..data.aiOn = true
      ..data.saved = ['A tip.']
      ..data.history = [
        Txn(
          id: '1',
          type: 'purchase',
          direction: 'out',
          amountHalalas: 90000,
          occurredAt: DateTime.utc(2026, 10, 30, 9),
          merchant: 'X',
          categoryId: 'c-din',
        ),
      ];
    h.data.txns = h.data.history;
    await t.pumpWidget(await h.build());
    await t.pumpAndSettle();
    await t.tap(find.text('Insights').last);
    await t.pumpAndSettle();
    await t.tap(find.text('Ask a question'));
    await t.pumpAndSettle();
    expect(find.text('Try asking'), findsOneWidget);
    await t.tap(find.text('Where can I cut spending?'));
    await t.pumpAndSettle();
    expect(find.text('Dining is 900.00 SAR.'), findsOneWidget);
    // Suggestions stay available after the answer.
    expect(find.text('Try asking'), findsOneWidget);
    expect(find.text('Am I on track with my budgets?'), findsOneWidget);
  });

  testWidgets('deleting a rule asks the repository to disable it', (t) async {
    _tall(t);
    final h = Harness(signedIn: true)
      ..data.rules = [
        const MerchantRule(id: 'r1', pattern: 'otten', categoryId: 'c-gro'),
      ];
    await t.pumpWidget(await h.build());
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('tab-item-4')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('more-rules')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('rule-delete-r1')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('confirm-yes')));
    await t.pumpAndSettle();
    expect(h.data.rules, isEmpty);
    expect(find.text('otten'), findsNothing);
  });
}
