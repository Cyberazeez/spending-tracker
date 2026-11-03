import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('English and Arabic have exactly the same message keys', () {
    Set<String> keys(String path) =>
        (jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>).keys
            .where((k) => !k.startsWith('@'))
            .toSet();
    final en = keys('lib/l10n/app_en.arb');
    final ar = keys('lib/l10n/app_ar.arb');
    expect(en.difference(ar), isEmpty, reason: 'missing in Arabic');
    expect(ar.difference(en), isEmpty, reason: 'missing in English');
  });
}
