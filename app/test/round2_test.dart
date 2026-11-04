import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:spending_tracker/core/models.dart';

import 'support/fakes.dart';

Txn spend(String id, int halalas, {String? cat}) => Txn(
  id: id,
  type: 'purchase',
  direction: 'out',
  amountHalalas: halalas,
  occurredAt: DateTime.now().toUtc(),
  merchant: 'A very long merchant name that needs room',
  merchantNorm: 'acme',
  categoryId: cat,
);

void main() {
  testWidgets(
    'a new account can set its monthly budget from the welcome card and from More',
    (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final h = Harness(signedIn: true)..data.accounts = [];
      await tester.pumpWidget(await h.build());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Set a monthly budget'));
      await tester.pumpAndSettle();
      // the amount prompt opens right here, no empty Insights page
      expect(find.byType(CupertinoTextField), findsOneWidget);
      await tester.enterText(find.byType(CupertinoTextField), '9000');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(h.data.monthlyBudget, 900000);

      await tester.tap(find.text('More').last);
      await tester.pumpAndSettle();
      expect(find.text('Monthly budget'), findsOneWidget);
      expect(find.textContaining('9,000.00'), findsWidgets);
      await tester.tap(find.text('Monthly budget'));
      await tester.pumpAndSettle();
      expect(find.text('Remove budget'), findsOneWidget);
      await tester.tap(find.text('Remove budget'));
      await tester.pumpAndSettle();
      expect(h.data.monthlyBudget, isNull);
      expect(find.text('Not set'), findsOneWidget);
      await tester.tap(find.text('Monthly budget'));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoTextField), findsOneWidget);
    },
  );

  testWidgets('the amount of a transaction sits at the end of its row', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final h = Harness(signedIn: true);
    h.data.txns = [spend('1', 2399, cat: 'c-din')];
    h.data.history = h.data.txns;
    await tester.pumpWidget(await h.build());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Activity').last);
    await tester.pumpAndSettle();
    final amount = find.textContaining('23.99').first;
    final right = tester.getTopRight(amount).dx;
    // the card's inner edge: the amount ends within a few points of it
    expect(right, greaterThan(400 - 16 - 14 - 8));
  });

  for (final lang in ['ar', 'en']) {
    testWidgets('row arrows point the right way in $lang', (tester) async {
      final h = Harness(signedIn: true);
      await tester.pumpWidget(await h.build(prefs: {'locale': lang}));
      await tester.pumpAndSettle();
      await tester.tap(find.text(lang == 'ar' ? 'المزيد' : 'More').last);
      await tester.pumpAndSettle();
      final want = lang == 'ar'
          ? LucideIcons.chevronLeft
          : LucideIcons.chevronRight;
      final icons = tester
          .widgetList<Icon>(find.byType(Icon))
          .where(
            (i) =>
                i.icon == LucideIcons.chevronLeft ||
                i.icon == LucideIcons.chevronRight,
          )
          .toList();
      expect(icons, isNotEmpty);
      expect(icons.every((i) => i.icon == want), isTrue);
    });
  }

  testWidgets('leaving the chat takes the keyboard with it', (tester) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final h = Harness(signedIn: true);
    h.data.aiOn = true;
    h.data.saved = ['x ⃁ 1'];
    h.data.history = [spend('1', 90000, cat: 'c-din')];
    h.data.txns = h.data.history;
    await tester.pumpWidget(await h.build());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Insights').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ask a question'));
    await tester.pumpAndSettle();
    await tester.showKeyboard(find.byType(CupertinoTextField));
    await tester.pumpAndSettle();
    expect(tester.testTextInput.isVisible, isTrue);
    await tester.tap(find.byType(CupertinoNavigationBarBackButton));
    await tester.pumpAndSettle();
    expect(find.text('Ask about your spending'), findsNothing);
    expect(tester.testTextInput.isVisible, isFalse);
  });

  testWidgets('the tips follow the app language', (tester) async {
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
    expect(find.textContaining('Cut dining'), findsOneWidget);
    h.data.saved = []; // nothing saved in Arabic yet
    h.data.tipsResult = const AiOutcome.ok(tips: ['قلل المطاعم: ⃁ 900']);
    await tester.tap(find.text('More').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Language'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('العربية').last);
    await tester.pumpAndSettle();
    expect(h.data.tipCalls, hasLength(1));
    expect(h.data.tipCalls.single.$2, 'ar');
    await tester.tap(find.text('التحليلات').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('قلل المطاعم'), findsOneWidget);
    expect(find.textContaining('Cut dining'), findsNothing);
  });
}
