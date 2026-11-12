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

ObligationInstance _bill(String id, String name, String due, int amount) =>
    ObligationInstance(
      id: id,
      obligationId: 'o-$id',
      name: name,
      kind: 'fixed',
      dueDate: DateTime.parse('${due}T00:00:00Z'),
      status: 'pending',
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
}
