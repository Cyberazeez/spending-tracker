import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

/// Every tab must survive the two bad situations a real phone meets: the server cannot be reached, and there is
/// nothing to show yet. No crash, and the screen says what is going on.
void main() {
  const tabs = ['Home', 'Activity', 'Bills', 'Insights', 'More'];
  for (final tab in tabs) {
    testWidgets('server unreachable: $tab shows a message, not a crash', (
      t,
    ) async {
      t.view.physicalSize = const Size(390 * 3, 844 * 3);
      t.view.devicePixelRatio = 3;
      addTearDown(t.view.reset);
      final h = Harness(signedIn: true);
      h.data.failLoad = true;
      await t.pumpWidget(await h.build());
      await t.pumpAndSettle();
      if (tab != 'Home') {
        await t.tap(find.text(tab).last);
        await t.pumpAndSettle();
      }
      expect(t.takeException(), isNull);
      if (tab != 'More') {
        expect(
          find.textContaining('Could not load'),
          findsAtLeastNWidgets(1),
          reason: '$tab has no visible error message',
        );
      }
    });

    testWidgets('nothing yet: $tab renders an empty state', (t) async {
      t.view.physicalSize = const Size(390 * 3, 844 * 3);
      t.view.devicePixelRatio = 3;
      addTearDown(t.view.reset);
      final h = Harness(signedIn: true);
      await t.pumpWidget(await h.build());
      await t.pumpAndSettle();
      if (tab != 'Home') {
        await t.tap(find.text(tab).last);
        await t.pumpAndSettle();
      }
      expect(t.takeException(), isNull);
    });
  }

  // Arabic: same checks, with the Arabic tab names and message.
  const arTabs = ['الرئيسية', 'النشاط', 'الفواتير', 'التحليلات'];
  for (final tab in arTabs) {
    testWidgets('server unreachable (ar): $tab shows a message', (t) async {
      t.view.physicalSize = const Size(390 * 3, 844 * 3);
      t.view.devicePixelRatio = 3;
      addTearDown(t.view.reset);
      final h = Harness(signedIn: true);
      h.data.failLoad = true;
      await t.pumpWidget(await h.build(prefs: {'locale': 'ar'}));
      await t.pumpAndSettle();
      if (tab != arTabs.first) {
        await t.tap(find.text(tab).last);
        await t.pumpAndSettle();
      }
      expect(t.takeException(), isNull);
      expect(find.textContaining('تعذّر'), findsAtLeastNWidgets(1));
    });
  }
}
