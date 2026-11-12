import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:spending_tracker/l10n/app_localizations.dart';
import 'package:spending_tracker/router.dart';
import 'package:spending_tracker/ui/choice_sheet.dart';
import 'package:spending_tracker/ui/empty_state.dart';
import 'package:spending_tracker/ui/halala_logo.dart';
import 'package:spending_tracker/ui/icon_tile.dart';
import 'package:spending_tracker/ui/settings_group.dart';

import 'support/fakes.dart';

const _ink = Color(0xFF0D1F17);
const _paper = Color(0xFFF0F5E6);

Widget _app(Widget child, {Brightness brightness = Brightness.light}) =>
    CupertinoApp(
      theme: CupertinoThemeData(brightness: brightness),
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
      ],
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(390, 800),
          platformBrightness: brightness,
        ),
        child: CupertinoPageScaffold(
          child: Center(child: SizedBox(width: 340, child: child)),
        ),
      ),
    );

double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  group('logo', () {
    test('the path of docs/brand/logo.svg is read whole', () {
      final b = parseSvgPath('M0 0 10 0 10 10Z M20 20L30 20Q35 25 30 30Z')
          .getBounds();
      expect(b, const Rect.fromLTRB(0, 0, 35, 30));
      expect(() => parseSvgPath('M0 0 C1 1 2 2 3 3'), throwsFormatException);
      final logo = HalalaLogoPainter(line: _ink, fill: _ink, coin: _ink);
      expect(logo, isNotNull);
    });

    testWidgets(
      'outline is paper in dark mode, ink in light, and VoiceOver reads the word',
      (t) async {
        for (final (mode, line) in [
          (Brightness.light, _ink),
          (Brightness.dark, _paper),
        ]) {
          await t.pumpWidget(_app(const HalalaLogo(), brightness: mode));
          final paint = t.widget<CustomPaint>(
            find.descendant(
              of: find.byType(HalalaLogo),
              matching: find.byType(CustomPaint),
            ),
          );
          final painter = paint.painter! as HalalaLogoPainter;
          expect(painter.line.toARGB32(), line.toARGB32());
          expect(painter.coin.toARGB32(), 0xFFFFC93C);
          expect(paint.size.width, 190);
          expect(paint.size.height, closeTo(190 * 1077 / 1719, 0.01));
        }
        expect(find.bySemanticsLabel('هللة'), findsOneWidget);
      },
    );
  });

  group('settings rows', () {
    testWidgets(
      'tile is an outlined pastel IconTile with an ink icon in dark mode',
      (t) async {
        await t.pumpWidget(
          _app(
            const SettingsGroup(
              children: [
                SettingsRow(
                  icon: LucideIcons.globe,
                  color: Color(0xFF9BE7E0),
                  title: 'Language',
                ),
                SettingsRow(
                  icon: LucideIcons.logOut,
                  color: Color(0xFF9BE7E0),
                  title: 'Remove',
                  danger: true,
                ),
              ],
            ),
            brightness: Brightness.dark,
          ),
        );
        final tiles = t.widgetList<IconTile>(find.byType(IconTile)).toList();
        expect(tiles.first.color, const Color(0xFF9BE7E0));
        expect(tiles.last.color, dangerTileColor);
        final icon = t.widget<Icon>(find.byIcon(LucideIcons.globe));
        final theme = IconTheme.of(t.element(find.byIcon(LucideIcons.globe)));
        expect((icon.color ?? theme.color)!.toARGB32(), _ink.toARGB32());
      },
    );

    testWidgets('switch track has the line-coloured outline', (t) async {
      await t.pumpWidget(
        _app(
          Builder(
            builder: (c) => appSwitch(c, value: false, onChanged: (_) {}),
          ),
          brightness: Brightness.dark,
        ),
      );
      final sw = t.widget<CupertinoSwitch>(find.byType(CupertinoSwitch));
      expect(sw.trackOutlineColor!.resolve({})!.toARGB32(), _paper.toARGB32());
      expect(sw.trackOutlineWidth!.resolve({}), 2);
    });
  });

  group('choice sheet', () {
    Future<void> open(
      WidgetTester t,
      List<ChoiceOption<String>> options,
    ) async {
      await t.pumpWidget(
        _app(
          Builder(
            builder: (c) => CupertinoButton(
              onPressed: () =>
                  showChoiceSheet<String>(c, title: 'Pick', options: options),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await t.tap(find.text('open'));
      await t.pumpAndSettle();
    }

    testWidgets(
      'a list with a current choice shows rings and a checked circle',
      (t) async {
        await open(t, const [
          ChoiceOption(value: 'en', label: 'English', selected: true),
          ChoiceOption(value: 'ar', label: 'Arabic'),
        ]);
        expect(find.byKey(const ValueKey('choice-selected')), findsOneWidget);
        expect(find.byIcon(LucideIcons.check), findsOneWidget);
        expect(
          t.getSemantics(find.bySemanticsLabel('English')),
          isSemantics(isSelected: true, isButton: true),
        );
      },
    );

    testWidgets('a list of actions has no rings', (t) async {
      await open(t, const [
        ChoiceOption(value: 'a', label: 'Edit'),
        ChoiceOption(value: 'b', label: 'Delete', destructive: true),
      ]);
      expect(find.byKey(const ValueKey('choice-selected')), findsNothing);
      // Only the outlined card per option: no 28 pt ring next to the label.
      final circles = find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration! as BoxDecoration).shape == BoxShape.circle &&
            w.constraints?.maxWidth == 28,
      );
      expect(circles, findsNothing);
    });
  });

  testWidgets('empty and failed states use the neutral sand tile', (t) async {
    await t.pumpWidget(
      _app(const EmptyState(icon: LucideIcons.triangleAlert, title: 'Failed')),
    );
    expect(t.widget<IconTile>(find.byType(IconTile)).color, emptyTileColor);
  });

  group('app screens', () {
    Future<Harness> signedIn(WidgetTester t, String path) async {
      final h = Harness(signedIn: true);
      await t.pumpWidget(await h.build());
      await t.pumpAndSettle();
      GoRouter.of(t.element(find.byType(CupertinoPageScaffold).last))
          .push(path);
      await t.pumpAndSettle();
      return h;
    }

    testWidgets('the back button is outlined, labelled and goes back', (
      t,
    ) async {
      await signedIn(t, accountPath);
      final back = find.byKey(const ValueKey('nav-back'));
      expect(back, findsOneWidget);
      expect(find.bySemanticsLabel('Back'), findsOneWidget);
      expect(
        find.descendant(
          of: back,
          matching: find.byIcon(LucideIcons.chevronLeft),
        ),
        findsOneWidget,
      );
      await t.tap(back);
      await t.pumpAndSettle();
      expect(back, findsNothing);
    });

    testWidgets('delete button label reads on the red in dark mode', (t) async {
      t.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(t.platformDispatcher.clearAllTestValues);
      await signedIn(t, deleteAccountPath);
      final box = t.widget<DecoratedBox>(
        find.byKey(const ValueKey('delete-button')),
      );
      final fill = (box.decoration as BoxDecoration).color!;
      final label = t.widget<Text>(find.text('Delete my account').last);
      expect(_contrast(label.style!.color!, fill), greaterThanOrEqualTo(4.5));
      expect((box.decoration as BoxDecoration).border, isNotNull);
    });

    testWidgets('bank account rows carry a tile per kind', (t) async {
      final h = Harness(signedIn: true);
      await t.pumpWidget(await h.build());
      await t.pumpAndSettle();
      GoRouter.of(t.element(find.byType(CupertinoPageScaffold).last))
          .push(banksPath);
      await t.pumpAndSettle();
      expect(find.byType(IconTile), findsOneWidget);
      expect(find.byIcon(LucideIcons.landmark), findsOneWidget);
    });

    testWidgets('sign in shows the logo', (t) async {
      final h = Harness();
      await t.pumpWidget(await h.build());
      await t.pumpAndSettle();
      expect(find.byType(HalalaLogo), findsOneWidget);
    });
  });
}
