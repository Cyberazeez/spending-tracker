import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/ui/tokens.dart';

double _lum(Color c) {
  double ch(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
}

double contrast(Color a, Color b) {
  final l1 = _lum(a), l2 = _lum(b);
  final hi = math.max(l1, l2), lo = math.min(l1, l2);
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  for (final brightness in Brightness.values) {
    final dark = brightness == Brightness.dark;
    testWidgets('tokens resolve and are readable (${brightness.name})', (
      tester,
    ) async {
      late BuildContext ctx;
      await tester.pumpWidget(
        CupertinoApp(
          theme: CupertinoThemeData(brightness: brightness),
          home: Builder(
            builder: (c) {
              ctx = c;
              return const SizedBox();
            },
          ),
        ),
      );
      Color r(CupertinoDynamicColor c) => Color(c.resolveFrom(ctx).toARGB32());
      expect(
        r(AppTokens.card),
        dark ? const Color(0xFF141A22) : const Color(0xFFFFFFFF),
      );
      expect(
        r(AppTokens.accent),
        dark ? const Color(0xFF3CC4A8) : const Color(0xFF0A7E6B),
      );
      expect(
        contrast(r(AppTokens.text), r(AppTokens.card)),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        contrast(r(AppTokens.muted), r(AppTokens.card)),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        contrast(r(AppTokens.muted), r(AppTokens.bg)),
        greaterThanOrEqualTo(4.5),
      );
    });
  }
}
