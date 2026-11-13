import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/core/models.dart';

import 'support/fakes.dart';

Future<Harness> _more(WidgetTester t, Harness h, {String lang = 'en'}) async {
  await t.pumpWidget(await h.build(prefs: {'locale': lang}));
  await t.pumpAndSettle();
  await t.tap(find.byKey(const ValueKey('tab-item-4')));
  await t.pumpAndSettle();
  return h;
}

void _tall(WidgetTester t) {
  t.view.physicalSize = const Size(800, 3000);
  t.view.devicePixelRatio = 2;
  addTearDown(t.view.reset);
}

void main() {
  testWidgets('More follows the mockup order', (t) async {
    _tall(t);
    await _more(t, Harness(signedIn: true));
    double y(String key) => t.getTopLeft(find.byKey(ValueKey(key))).dy;
    final order = [
      'more-account',
      'more-rules',
      'more-banks',
      'more-capture',
      'more-ai',
      'more-reminders',
    ];
    for (var i = 1; i < order.length; i++) {
      expect(y(order[i]) > y(order[i - 1]), isTrue, reason: order[i]);
    }
    expect(
      t.getTopLeft(find.text('Monthly budget')).dy < y('more-rules'),
      isTrue,
    );
    expect(t.getTopLeft(find.text('Language')).dy > y('more-ai'), isTrue);
    expect(
      t.getTopLeft(find.text('Sign out')).dy > y('more-reminders'),
      isTrue,
    );
  });

  testWidgets('the account card shows the email and opens Account', (t) async {
    _tall(t);
    final h = await _more(t, Harness(signedIn: true));
    expect(find.text('Your account'), findsOneWidget);
    expect(find.text(h.auth.email!), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('more-account')));
    await t.pumpAndSettle();
    expect(find.text('Profile'), findsOneWidget);
    // Bank accounts moved to More.
    expect(find.text('Bank accounts'), findsNothing);
  });

  testWidgets('Bank accounts shows how many there are and opens the list', (
    t,
  ) async {
    _tall(t);
    final h = Harness(signedIn: true)
      ..data.accounts = [
        const OwnAccount(
          id: 'a',
          bank: 'alinma',
          last4: '6000',
          kind: 'current',
        ),
        const OwnAccount(id: 'b', bank: 'snb', last4: '1111', kind: 'current'),
        const OwnAccount(id: 'c', bank: 'barq', last4: '2222', kind: 'wallet'),
      ];
    await _more(t, h);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('more-banks')),
        matching: find.text('3'),
      ),
      findsOneWidget,
    );
    await t.tap(find.byKey(const ValueKey('more-banks')));
    await t.pumpAndSettle();
    expect(find.text('Alinma Bank 6000'), findsOneWidget);
  });

  group('Categories and rules', () {
    Future<Harness> openRules(WidgetTester t, {bool fail = false}) async {
      _tall(t);
      final h = Harness(signedIn: true)
        ..data.failRules = fail
        ..data.rules = [
          const MerchantRule(id: 'r1', pattern: 'otten', categoryId: 'c-gro'),
          const MerchantRule(id: 'r2', pattern: 'danube', categoryId: 'c-gro'),
          const MerchantRule(
            id: 'r3',
            pattern: 'starbucks',
            categoryId: 'c-din',
          ),
        ];
      await _more(t, h);
      await t.tap(find.byKey(const ValueKey('more-rules')));
      await t.pumpAndSettle();
      return h;
    }

    testWidgets('lists each category with its places', (t) async {
      await openRules(t);
      expect(find.text('Categories and rules'), findsWidgets);
      expect(find.text('otten'), findsOneWidget);
      expect(find.text('danube'), findsOneWidget);
      expect(find.text('starbucks'), findsOneWidget);
      expect(find.text('2 rules'), findsOneWidget);
      expect(find.text('1 rule'), findsOneWidget);
    });

    testWidgets('deleting a rule asks first; Cancel keeps it', (t) async {
      final h = await openRules(t);
      await t.tap(find.byKey(const ValueKey('rule-delete-r1')));
      await t.pumpAndSettle();
      expect(find.text('Delete this rule?'), findsOneWidget);
      expect(find.textContaining('"otten"'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('confirm-no')));
      await t.pumpAndSettle();
      expect(h.data.rules, hasLength(3));
      await t.tap(find.byKey(const ValueKey('rule-delete-r1')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('confirm-yes')));
      await t.pumpAndSettle();
      expect(h.data.rules.map((r) => r.id), ['r2', 'r3']);
      expect(find.text('otten'), findsNothing);
      expect(find.text('1 rule'), findsNWidgets(2));
    });

    testWidgets('a failed load offers to try again', (t) async {
      final h = await openRules(t, fail: true);
      expect(find.text('Could not load'), findsOneWidget);
      h.data.failRules = false;
      await t.tap(find.text('Try again'));
      await t.pumpAndSettle();
      expect(find.text('otten'), findsOneWidget);
    });

    testWidgets('no rules explains how they are made', (t) async {
      _tall(t);
      await _more(t, Harness(signedIn: true));
      await t.tap(find.byKey(const ValueKey('more-rules')));
      await t.pumpAndSettle();
      expect(find.textContaining('No rules yet'), findsOneWidget);
    });
  });

  testWidgets('VoiceOver can activate the account card and a rule delete', (
    t,
  ) async {
    _tall(t);
    final handle = t.ensureSemantics();
    final h = Harness(signedIn: true)
      ..data.rules = [
        const MerchantRule(id: 'r1', pattern: 'otten', categoryId: 'c-gro'),
      ];
    await _more(t, h);
    expect(
      t.getSemantics(find.byKey(const ValueKey('more-account'))),
      matchesSemantics(
        isButton: true,
        hasTapAction: true,
        label: 'Your account, ${h.auth.email}',
      ),
    );
    await t.tap(find.byKey(const ValueKey('more-rules')));
    await t.pumpAndSettle();
    expect(
      t.getSemantics(find.byKey(const ValueKey('rule-delete-r1'))),
      matchesSemantics(
        isButton: true,
        hasTapAction: true,
        label: 'Delete rule, otten',
      ),
    );
    handle.dispose();
  });

  for (final lang in ['en', 'ar']) {
    testWidgets('More and Categories and rules survive 2x text ($lang)', (
      t,
    ) async {
      t.view.physicalSize = const Size(720, 1600);
      t.view.devicePixelRatio = 2;
      t.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(t.view.reset);
      addTearDown(t.platformDispatcher.clearAllTestValues);
      final h = Harness(signedIn: true)
        ..data.monthlyBudget = 600000
        ..data.rules = [
          const MerchantRule(
            id: 'r1',
            pattern: 'a very long merchant name for the rule list',
            categoryId: 'c-gro',
          ),
        ];
      await _more(t, h, lang: lang);
      expect(t.takeException(), isNull);
      final rules = find.byKey(const ValueKey('more-rules'));
      await t.scrollUntilVisible(
        rules,
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await t.pumpAndSettle();
      await t.tap(rules);
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    });
  }
}
