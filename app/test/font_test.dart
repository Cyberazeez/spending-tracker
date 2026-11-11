import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/core/money.dart';
import 'package:spending_tracker/ui/theme.dart';

void main() {
  test('Rubik is the app typeface and the riyal font stays the fallback', () {
    final t = appTheme.textTheme;
    for (final s in [
      t.textStyle,
      t.navTitleTextStyle,
      t.navLargeTitleTextStyle,
      t.actionTextStyle,
    ]) {
      expect(s.fontFamily, 'Rubik');
      expect(s.fontFamilyFallback, contains(riyalFont));
    }
  });

  test('the four Rubik weights are bundled and listed in pubspec', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    for (final w in ['Regular', 'Medium', 'Bold', 'ExtraBold']) {
      final path = 'assets/fonts/Rubik-$w.ttf';
      expect(File(path).existsSync(), isTrue, reason: path);
      expect(pubspec, contains(path));
    }
  });
}
