import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

/// Flutter's own accessibility checks on every tab, in both languages: tap targets at least 44 x 44 on iOS,
/// every tappable thing has a spoken label.
void main() {
  for (final lang in ['en', 'ar']) {
    final tabs = lang == 'en'
        ? ['Home', 'Activity', 'Bills', 'Insights', 'More']
        : ['الرئيسية', 'النشاط', 'الفواتير', 'التحليلات', 'المزيد'];
    for (final tab in tabs) {
      testWidgets('tap targets and labels: $tab ($lang)', (t) async {
        t.view.physicalSize = const Size(390 * 3, 844 * 3);
        t.view.devicePixelRatio = 3;
        addTearDown(t.view.reset);
        final handle = t.ensureSemantics();
        final h = Harness(signedIn: true);
        await t.pumpWidget(await h.build(prefs: {'locale': lang}));
        await t.pumpAndSettle();
        if (tab != tabs.first) {
          await t.tap(find.text(tab).last);
          await t.pumpAndSettle();
        }
        await expectLater(t, meetsGuideline(iOSTapTargetGuideline));
        await expectLater(t, meetsGuideline(labeledTapTargetGuideline));
        handle.dispose();
      });
    }
  }

  // Dynamic Type: the largest common setting (2x) on a small phone must not overflow anywhere.
  for (final lang in ['en', 'ar']) {
    final tabs = lang == 'en'
        ? ['Home', 'Activity', 'Bills', 'Insights', 'More']
        : ['الرئيسية', 'النشاط', 'الفواتير', 'التحليلات', 'المزيد'];
    for (final tab in tabs) {
      testWidgets('2x text, small phone: $tab ($lang)', (t) async {
        t.view.physicalSize = const Size(360 * 2, 720 * 2);
        t.view.devicePixelRatio = 2;
        t.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(t.view.reset);
        addTearDown(t.platformDispatcher.clearAllTestValues);
        final h = Harness(signedIn: true);
        await t.pumpWidget(await h.build(prefs: {'locale': lang}));
        await t.pumpAndSettle();
        if (tab != tabs.first) {
          await t.tap(find.text(tab).last);
          await t.pumpAndSettle();
        }
        expect(t.takeException(), isNull);
      });
    }
  }
}
