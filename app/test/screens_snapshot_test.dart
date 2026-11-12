import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:spending_tracker/core/models.dart';
import 'package:spending_tracker/router.dart';

import 'support/fakes.dart';

/// Writes a picture of every tab (light and dark, English and Arabic) to `build/snapshots/`, with the real
/// fonts loaded. Nothing is compared: it only fails if a screen throws while it is drawn. Look at the pictures
/// after a change to the design layer.
Future<void> _font(String family, List<String> paths) async {
  final loader = FontLoader(family);
  for (final p in paths) {
    loader.addFont(rootBundle.load(p));
  }
  await loader.load();
}

// The harness clock is 2026-10-30 12:00 UTC.
Txn _tx(String id, String when, int h, String? cat, String merchant) => Txn(
  id: id,
  type: 'purchase',
  direction: 'out',
  amountHalalas: h,
  occurredAt: DateTime.parse('${when}Z'),
  merchant: merchant,
  merchantNorm: merchant.toLowerCase(),
  categoryId: cat,
);

ObligationInstance _bill(
  String id,
  String name,
  String due,
  int amount, {
  String status = 'pending',
}) => ObligationInstance(
  id: id,
  obligationId: 'o-$id',
  name: name,
  kind: 'fixed',
  dueDate: DateTime.parse('${due}T00:00:00Z'),
  status: status,
  expectedHalalas: amount,
);

void _sample(Harness h) {
  final txns = [
    _tx('1', '2026-10-30T09:10:00', 1800, 'c-din', 'Coffee'),
    _tx('2', '2026-10-30T08:00:00', 16450, 'c-gro', 'Supermarket'),
    _tx('3', '2026-10-29T18:30:00', 8600, 'c-din', 'Restaurant'),
    _tx('7', '2026-10-29T21:40:00', 12000, null, 'Online order'),
    _tx('4', '2026-10-27T12:00:00', 23000, 'c-gro', 'Supermarket'),
    _tx('5', '2026-10-25T20:15:00', 31000, 'c-din', 'Grill house'),
    _tx('6', '2026-10-12T10:00:00', 120000, 'c-gro', 'Wholesale'),
  ];
  h.data
    ..txns = txns
    ..history = txns
    ..monthlyBudget = 600000
    ..budgetList = [
      const Budget(id: 'b', categoryId: 'c-din', limitHalalas: 50000),
    ]
    ..instances = [
      _bill('1', 'Mobile bill', '2026-11-02', 23000),
      _bill('2', 'Horse stable', '2026-11-05', 120000),
      _bill('3', 'Car loan', '2026-11-20', 50000),
      _bill('4', 'Electricity bill', '2026-10-20', 38500),
      _bill('5', 'Internet', '2026-10-15', 29000, status: 'paid'),
      _bill('6', 'Water bill', '2026-10-31', 12000),
    ]
    ..review = [
      RawMessage(
        id: 'r1',
        sender: 'Bank',
        body: 'Purchase 75.00 SAR card **4821 at [merchant] on 29/10',
        receivedAt: DateTime.parse('2026-10-29T11:20:00Z'),
      ),
    ];
}

Future<void> _save(WidgetTester t, String name) async {
  expect(t.takeException(), isNull);
  final dir = Directory('build/snapshots')..createSync(recursive: true);
  final old = autoUpdateGoldenFiles;
  autoUpdateGoldenFiles = true;
  try {
    await expectLater(
      find.byType(CupertinoApp),
      matchesGoldenFile('${dir.absolute.path}/$name.png'),
    );
  } finally {
    autoUpdateGoldenFiles = old;
  }
}

/// Sub-screens and sheets of the Activity tab (rebrand stage 2).
const _activityScreens = ['quickadd', 'review', 'category', 'filter'];

void main() {
  setUpAll(() async {
    await _font('Rubik', [
      for (final w in ['Regular', 'Medium', 'Bold', 'ExtraBold'])
        'assets/fonts/Rubik-$w.ttf',
    ]);
    await _font('SaudiRiyal', [
      'assets/fonts/SaudiRiyal-Regular.ttf',
      'assets/fonts/SaudiRiyal-Bold.ttf',
    ]);
    await _font('packages/lucide_icons_flutter/Lucide', [
      'packages/lucide_icons_flutter/assets/lucide.ttf',
    ]);
    await _font('packages/cupertino_icons/CupertinoIcons', [
      'packages/cupertino_icons/assets/CupertinoIcons.ttf',
    ]);
  });

  for (final lang in ['en', 'ar']) {
    final tabs = lang == 'en'
        ? ['Home', 'Activity', 'Bills', 'Insights', 'More']
        : ['الرئيسية', 'النشاط', 'الفواتير', 'التحليلات', 'المزيد'];
    for (final mode in Brightness.values) {
      for (var i = 0; i < tabs.length; i++) {
        testWidgets('snapshot: ${tabs[i]} ($lang, ${mode.name})', (t) async {
          t.view.physicalSize = const Size(390 * 2, 844 * 2);
          t.view.devicePixelRatio = 2;
          t.platformDispatcher.platformBrightnessTestValue = mode;
          addTearDown(t.view.reset);
          addTearDown(t.platformDispatcher.clearAllTestValues);
          final h = Harness(signedIn: true);
          _sample(h);
          await t.pumpWidget(await h.build(prefs: {'locale': lang}));
          await t.pumpAndSettle();
          if (i != 0) {
            await t.tap(find.text(tabs[i]).last);
            await t.pumpAndSettle();
          }
          expect(t.takeException(), isNull);
          final dir = Directory('build/snapshots')..createSync(recursive: true);
          final old = autoUpdateGoldenFiles;
          autoUpdateGoldenFiles = true;
          try {
            await expectLater(
              find.byType(CupertinoApp),
              matchesGoldenFile(
                '${dir.absolute.path}/${lang}_${mode.name}_$i.png',
              ),
            );
          } finally {
            autoUpdateGoldenFiles = old;
          }
        });
      }
    }
  }

  for (final lang in ['en', 'ar']) {
    final activity = lang == 'en' ? 'Activity' : 'النشاط';
    for (final mode in Brightness.values) {
      for (final screen in _activityScreens) {
        testWidgets('snapshot: $screen ($lang, ${mode.name})', (t) async {
          t.view.physicalSize = const Size(390 * 2, 844 * 2);
          t.view.devicePixelRatio = 2;
          t.platformDispatcher.platformBrightnessTestValue = mode;
          addTearDown(t.view.reset);
          addTearDown(t.platformDispatcher.clearAllTestValues);
          final h = Harness(signedIn: true);
          _sample(h);
          await t.pumpWidget(await h.build(prefs: {'locale': lang}));
          await t.pumpAndSettle();
          await t.tap(find.text(activity).last);
          await t.pumpAndSettle();
          final ctx = t.element(find.byType(CupertinoPageScaffold).last);
          switch (screen) {
            case 'quickadd':
              GoRouter.of(ctx).push(quickAddPath);
            case 'review':
              GoRouter.of(ctx).push(reviewPath);
            case 'category':
              await t.tap(find.text('Online order'));
            case 'filter':
              await t.tap(find.byIcon(LucideIcons.listFilter));
          }
          await t.pumpAndSettle();
          await _save(t, '${lang}_${mode.name}_activity_$screen');
        });
      }
    }
  }

  // Rebrand stage 3: Bills and Insights sub-screens and sheets.
  const stage3 = ['form', 'actions', 'amount', 'confirm', 'ai_tips', 'chat'];
  for (final lang in ['en', 'ar']) {
    final en = lang == 'en';
    for (final mode in Brightness.values) {
      for (final screen in stage3) {
        testWidgets('snapshot: $screen ($lang, ${mode.name})', (t) async {
          t.view.physicalSize = const Size(390 * 2, 844 * 2);
          t.view.devicePixelRatio = 2;
          t.platformDispatcher.platformBrightnessTestValue = mode;
          addTearDown(t.view.reset);
          addTearDown(t.platformDispatcher.clearAllTestValues);
          final h = Harness(signedIn: true);
          _sample(h);
          h.data
            ..aiOn = true
            ..aiPaid = true
            ..saved = [
              'Dining is 38% above your 3-month average.',
              'Two coffee shops make up most of it.',
            ];
          await t.pumpWidget(await h.build(prefs: {'locale': lang}));
          await t.pumpAndSettle();
          Future<void> tab(String name) async {
            await t.tap(find.text(name).last);
            await t.pumpAndSettle();
          }

          final bills = en ? 'Bills' : 'الفواتير';
          switch (screen) {
            case 'form':
              await tab(bills);
              GoRouter.of(t.element(find.byType(CupertinoPageScaffold).last))
                  .push(obligationFormPath);
            case 'actions':
              await tab(bills);
              await t.tap(find.text('Electricity bill').first);
            case 'amount':
              await tab(bills);
              await t.tap(find.text('Electricity bill').first);
              await t.pumpAndSettle();
              await t.tap(find.text(en ? 'Edit amount' : 'تعديل المبلغ'));
            case 'confirm':
              await tab(bills);
              await t.tap(find.text('Electricity bill').first);
              await t.pumpAndSettle();
              await t.tap(find.text(en ? 'Stop tracking' : 'إيقاف المتابعة'));
            case 'ai_tips':
              await tab(en ? 'Insights' : 'التحليلات');
            case 'chat':
              GoRouter.of(t.element(find.byType(CupertinoPageScaffold).last))
                  .push(aiChatPath);
              await t.pumpAndSettle();
              await t.enterText(
                find.byType(CupertinoTextField).last,
                en ? 'How much on dining?' : 'كم صرفت على المطاعم؟',
              );
              await t.pump();
              await t.tap(find.byIcon(LucideIcons.arrowUp));
          }
          await t.pumpAndSettle();
          await _save(t, '${lang}_${mode.name}_s3_$screen');
        });
      }
    }
  }

  // Rebrand stage 4: start screens and the More family.
  const stage4 = [
    'lock',
    'login',
    'signup',
    'forgot',
    'account',
    'banks',
    'banks_error',
    'capture',
    'guide',
    'guide_last',
    'delete',
    'language',
    'home_empty',
  ];
  for (final lang in ['en', 'ar']) {
    final en = lang == 'en';
    for (final mode in Brightness.values) {
      for (final screen in stage4) {
        testWidgets('snapshot: $screen ($lang, ${mode.name})', (t) async {
          t.view.physicalSize = const Size(390 * 2, 844 * 2);
          t.view.devicePixelRatio = 2;
          t.platformDispatcher.platformBrightnessTestValue = mode;
          addTearDown(t.view.reset);
          addTearDown(t.platformDispatcher.clearAllTestValues);
          final signedOut = const ['login', 'signup', 'forgot'];
          final h = Harness(signedIn: !signedOut.contains(screen));
          if (screen != 'home_empty') _sample(h);
          h.data.accounts = [
            const OwnAccount(
              id: 'oa1',
              bank: 'alinma',
              last4: '6000',
              kind: 'account',
              label: 'Main',
            ),
            const OwnAccount(
              id: 'oa2',
              bank: 'alinma',
              last4: '7730',
              kind: 'credit_card',
            ),
            const OwnAccount(
              id: 'oa3',
              bank: 'mobilypay',
              last4: '0912',
              kind: 'wallet',
            ),
          ];
          if (screen == 'lock') h.authenticator.result = false;
          if (screen == 'banks_error') h.data.failLoad = true;
          await t.pumpWidget(await h.build(prefs: {'locale': lang}));
          await t.pumpAndSettle();
          void go(String path) =>
              GoRouter.of(t.element(find.byType(CupertinoPageScaffold).last))
                  .push(path);
          switch (screen) {
            case 'signup':
              go(signUpPath);
            case 'forgot':
              go(forgotPath);
            case 'account':
              go(accountPath);
            case 'banks' || 'banks_error':
              go(banksPath);
            case 'capture':
              go(capturePath);
            case 'guide' || 'guide_last':
              go(capturePath);
              await t.pumpAndSettle();
              await t.tap(
                find.text(en ? 'Show me how, step by step' : 'اعرض لي الخطوات'),
              );
              await t.pumpAndSettle();
              if (screen == 'guide_last') {
                for (var i = 0; i < 6; i++) {
                  await t.tap(find.byKey(const ValueKey('guide-next')));
                  await t.pumpAndSettle();
                }
              }
            case 'delete':
              go(deleteAccountPath);
            case 'language':
              await t.tap(find.text(en ? 'More' : 'المزيد').last);
              await t.pumpAndSettle();
              await t.tap(find.text(en ? 'Language' : 'اللغة'));
          }
          await t.pumpAndSettle();
          await _save(t, '${lang}_${mode.name}_s4_$screen');
        });
      }
    }
  }
}
