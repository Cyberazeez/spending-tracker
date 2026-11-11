import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/ui/app_card.dart';
import 'package:spending_tracker/ui/app_form.dart';
import 'package:spending_tracker/ui/pill_tab_bar.dart';
import 'package:spending_tracker/ui/tokens.dart';

Widget _app(
  Widget child, {
  Brightness brightness = Brightness.light,
  TextDirection direction = TextDirection.ltr,
  double textScale = 1,
  double width = 390,
}) => CupertinoApp(
  theme: CupertinoThemeData(brightness: brightness),
  home: MediaQuery(
    data: MediaQueryData(
      size: Size(width, 800),
      textScaler: TextScaler.linear(textScale),
      platformBrightness: brightness,
    ),
    child: Directionality(
      textDirection: direction,
      child: Center(
        child: SizedBox(width: width, child: child),
      ),
    ),
  ),
);

/// The first outlined box inside [scope] (skips the undecorated boxes Cupertino widgets add).
BoxDecoration _decorationIn(WidgetTester t, Finder scope) => t
    .widgetList<DecoratedBox>(
      find.descendant(of: scope, matching: find.byType(DecoratedBox)),
    )
    .map((d) => d.decoration)
    .whereType<BoxDecoration>()
    .firstWhere((d) => d.border != null);

void main() {
  for (final b in Brightness.values) {
    final line = b == Brightness.dark
        ? const Color(0xFFF0F5E6)
        : const Color(0xFF0D1F17);

    testWidgets('AppCard: ink outline and hard shadow (${b.name})', (t) async {
      await t.pumpWidget(
        _app(const AppCard(child: SizedBox(height: 40)), brightness: b),
      );
      final d = _decorationIn(t, find.byType(AppCard));
      final border = d.border! as Border;
      expect(border.top.width, 2.5);
      expect(border.top.color.toARGB32(), line.toARGB32());
      expect(d.boxShadow, hasLength(1));
      expect(d.boxShadow!.single.blurRadius, 0);
      expect(d.boxShadow!.single.offset, const Offset(4, 5));
      expect(d.boxShadow!.single.color.toARGB32(), line.toARGB32());
      // The shadow lies inside the card's own box, so a clip at its edge cannot cut it.
      final card = t.getRect(find.byType(AppCard));
      final box = t.getRect(
        find
            .descendant(
              of: find.byType(AppCard),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      expect(card.right - box.right, greaterThanOrEqualTo(4));
      expect(card.bottom - box.bottom, greaterThanOrEqualTo(5));
    });

    testWidgets('AppCard flat: outline, no shadow (${b.name})', (t) async {
      await t.pumpWidget(
        _app(
          const AppCard(flat: true, child: SizedBox(height: 40)),
          brightness: b,
        ),
      );
      final d = _decorationIn(t, find.byType(AppCard));
      expect(d.border, isNotNull);
      expect(d.boxShadow, isNull);
    });

    testWidgets('PrimaryButton: enabled and disabled look (${b.name})', (
      t,
    ) async {
      await t.pumpWidget(
        _app(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PrimaryButton(label: 'Save', onPressed: () {}),
              const PrimaryButton(label: 'Wait', onPressed: null),
            ],
          ),
          brightness: b,
        ),
      );
      final on = _decorationIn(t, find.byType(PrimaryButton).first);
      final off = _decorationIn(t, find.byType(PrimaryButton).last);
      expect(on.boxShadow!.single.offset, const Offset(3, 4));
      expect(on.border, isNotNull);
      expect(off.boxShadow, isNull);
      expect(off.color, isNot(on.color));
      // Ink on the brand fill in both modes; the disabled label is the muted colour, not a faded one.
      expect(
        t.widget<Text>(find.text('Save')).style!.color!.toARGB32(),
        0xFF0D1F17,
      );
      final ctx = t.element(find.text('Wait'));
      expect(
        t.widget<Text>(find.text('Wait')).style!.color!.toARGB32(),
        AppTokens.muted.resolveFrom(ctx).toARGB32(),
      );
      expect(
        t.getSize(find.byType(PrimaryButton).first).height,
        greaterThanOrEqualTo(44),
      );
    });
  }

  testWidgets('PrimaryButton: 2x text on a 360 wide phone does not overflow', (
    t,
  ) async {
    await t.pumpWidget(
      _app(
        PrimaryButton(label: 'Set up SMS capture', onPressed: () {}),
        textScale: 2,
        width: 360,
      ),
    );
    expect(t.takeException(), isNull);
  });

  for (final dir in TextDirection.values) {
    testWidgets('PillTabBar: selected pill, labels, taps (${dir.name})', (
      t,
    ) async {
      int? tapped;
      await t.pumpWidget(
        _app(
          PillTabBar(
            currentIndex: 1,
            onTap: (i) => tapped = i,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(CupertinoIcons.house),
                label: 'One',
              ),
              BottomNavigationBarItem(
                icon: Icon(CupertinoIcons.list_bullet),
                label: 'Two',
              ),
              BottomNavigationBarItem(
                icon: Icon(CupertinoIcons.ellipsis),
                label: 'Three',
              ),
            ],
          ),
          direction: dir,
        ),
      );
      // Every label stays visible; only the selected one sits on the brand pill.
      for (final l in ['One', 'Two', 'Three']) {
        expect(find.text(l), findsOneWidget);
      }
      final pills = t
          .widgetList<DecoratedBox>(
            find.descendant(
              of: find.byType(PillTabBar),
              matching: find.byType(DecoratedBox),
            ),
          )
          .map((d) => d.decoration as BoxDecoration)
          .where((d) => d.color?.toARGB32() == 0xFF00A86B);
      expect(pills, hasLength(1));
      expect(
        t.widget<Text>(find.text('Two')).style!.color!.toARGB32(),
        0xFF0D1F17,
      );
      await t.tap(find.text('Three'));
      expect(tapped, 2);
      // Right to left: the first tab is on the right.
      final one = t.getCenter(find.text('One')).dx;
      final three = t.getCenter(find.text('Three')).dx;
      expect(dir == TextDirection.rtl ? one > three : one < three, isTrue);
      // The outer pill carries the outline and the hard shadow.
      final outer = _decorationIn(t, find.byType(PillTabBar));
      expect(outer.border, isNotNull);
      expect(outer.boxShadow!.single.blurRadius, 0);
    });
  }
}
