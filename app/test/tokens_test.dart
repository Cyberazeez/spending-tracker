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
      Color hex(int light, int darkV) => Color(dark ? darkV : light);
      expect(r(AppTokens.bg), hex(0xFFF0F5E6, 0xFF0D1F17));
      expect(r(AppTokens.card), hex(0xFFFFFFFF, 0xFF173326));
      expect(r(AppTokens.text), hex(0xFF0D1F17, 0xFFF0F5E6));
      expect(r(AppTokens.accent), hex(0xFF00A86B, 0xFF3FD79B));
      expect(r(AppTokens.accentText), hex(0xFF00704A, 0xFF3FD79B));
      expect(r(AppTokens.line), hex(0xFF0D1F17, 0xFFF0F5E6));
      expect(r(AppTokens.gold), hex(0xFFFFC93C, 0xFFFFC93C));
      expect(r(AppTokens.danger), hex(0xFFD11A3F, 0xFFFF9DB0));
      final pairs = {
        'text on card': (AppTokens.text, AppTokens.card),
        'text on bg': (AppTokens.text, AppTokens.bg),
        'muted on card': (AppTokens.muted, AppTokens.card),
        'muted on bg': (AppTokens.muted, AppTokens.bg),
        'accentText on card': (AppTokens.accentText, AppTokens.card),
        'accentText on bg': (AppTokens.accentText, AppTokens.bg),
        'onAccent on accent': (AppTokens.onAccent, AppTokens.accent),
        'danger on card': (AppTokens.danger, AppTokens.card),
        'danger on bg': (AppTokens.danger, AppTokens.bg),
        'warnText on card': (AppTokens.warnText, AppTokens.card),
        'warnText on bg': (AppTokens.warnText, AppTokens.bg),
        'onTint on warnBg': (AppTokens.onTint, AppTokens.warnBg),
        'okText on okBg': (AppTokens.okText, AppTokens.okBg),
      };
      for (final e in pairs.entries) {
        expect(
          contrast(r(e.value.$1), r(e.value.$2)),
          greaterThanOrEqualTo(4.5),
          reason: e.key,
        );
      }
      final shadow = hardShadowOf(ctx);
      expect(shadow, hasLength(1));
      expect(shadow.single.blurRadius, 0);
      expect(shadow.single.offset, const Offset(4, 5));
      expect(shadow.single.color.toARGB32(), r(AppTokens.line).toARGB32());
      expect(outlineOf(ctx).top.width, 2.5);
    });
  }
}
