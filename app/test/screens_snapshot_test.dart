import 'dart:io';
import 'dart:ui' show Brightness, Size;

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
