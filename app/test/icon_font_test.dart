import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  // Widget tests never draw glyphs, so a missing icon font only shows on a real device (every icon becomes a "?" box).
  test('the Cupertino icon font package is a dependency', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains(RegExp(r'^\s*cupertino_icons:', multiLine: true)));
  });
}
