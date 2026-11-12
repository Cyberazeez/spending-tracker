import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/l10n/app_localizations.dart';
import 'package:spending_tracker/ui/app_card.dart';
import 'package:spending_tracker/ui/app_form.dart';
import 'package:spending_tracker/ui/app_sheet.dart';
import 'package:spending_tracker/ui/halala_logo.dart';
import 'package:spending_tracker/ui/press.dart';

import 'support/fakes.dart';

Widget _app(Widget child, {bool reduce = false}) => CupertinoApp(
  locale: const Locale('en'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
  ],
  builder: (context, c) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: reduce),
    child: c!,
  ),
  home: CupertinoPageScaffold(
    child: Center(child: SizedBox(width: 300, child: child)),
  ),
);

/// The translation the [Pressable] applies right now.
Offset _shift(WidgetTester t) {
  final tr = t.widget<Transform>(
    find
        .descendant(
          of: find.byType(Pressable),
          matching: find.byType(Transform),
        )
        .first,
  );
  final v = tr.transform.getTranslation();
  return Offset(v.x, v.y);
}

double _opacity(WidgetTester t) => t
    .widget<Opacity>(
      find
          .descendant(
            of: find.byType(Pressable),
            matching: find.byType(Opacity),
          )
          .first,
    )
    .opacity;

void main() {
  group('press', () {
    testWidgets(
      'a button sinks into its shadow while held and fires on release only',
      (t) async {
        var taps = 0;
        await t.pumpWidget(
          _app(PrimaryButton(label: 'Save', onPressed: () => taps++)),
        );
        expect(_shift(t), Offset.zero);
        final g = await t.startGesture(t.getCenter(find.text('Save')));
        await t.pump();
        await t.pump(const Duration(milliseconds: 100));
        expect(_shift(t), const Offset(3, 4));
        expect(taps, 0);
        await g.up();
        await t.pump();
        expect(taps, 1);
        await t.pumpAndSettle();
        expect(_shift(t).distance, lessThan(0.01));
      },
    );

    testWidgets(
      'a quick tap still shows the press, then springs back past rest',
      (t) async {
        await t.pumpWidget(_app(PrimaryButton(label: 'Go', onPressed: () {})));
        final g = await t.startGesture(t.getCenter(find.text('Go')));
        await t.pump(const Duration(milliseconds: 16));
        await g.up();
        var deepest = 0.0, highest = 0.0;
        for (var i = 0; i < 40; i++) {
          await t.pump(const Duration(milliseconds: 10));
          final dy = _shift(t).dy;
          if (dy > deepest) deepest = dy;
          if (dy < highest) highest = dy;
        }
        expect(deepest, closeTo(4, 0.01));
        expect(highest, lessThan(0)); // the small bounce above rest
        expect(highest, greaterThan(-1));
      },
    );

    testWidgets('a disabled button does not move', (t) async {
      await t.pumpWidget(
        _app(const PrimaryButton(label: 'Off', onPressed: null)),
      );
      final g = await t.startGesture(t.getCenter(find.text('Off')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 100));
      expect(_shift(t), Offset.zero);
      await g.up();
    });

    testWidgets('a card under a finger that scrolls lets go', (t) async {
      await t.pumpWidget(
        _app(
          SizedBox(
            height: 400,
            child: ListView(
              children: [
                GestureDetector(
                  onTap: () {},
                  child: const AppCard(pressable: true, child: Text('Card')),
                ),
                const SizedBox(height: 800),
              ],
            ),
          ),
        ),
      );
      final g = await t.startGesture(t.getCenter(find.text('Card')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 100));
      expect(_shift(t), const Offset(4, 5));
      await g.moveBy(const Offset(0, -60));
      await t.pumpAndSettle();
      expect(_shift(t).distance, lessThan(0.01));
      await g.up();
    });

    testWidgets('with Reduce Motion nothing moves: the button fades', (
      t,
    ) async {
      await t.pumpWidget(
        _app(PrimaryButton(label: 'Save', onPressed: () {}), reduce: true),
      );
      final g = await t.startGesture(t.getCenter(find.text('Save')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 120));
      expect(
        find.descendant(
          of: find.byType(Pressable),
          matching: find.byType(Transform),
        ),
        findsNothing,
      );
      expect(_opacity(t), closeTo(0.6, 0.01));
      await g.up();
      await t.pumpAndSettle();
      expect(_opacity(t), 1);
    });
  });

  group('sheet', () {
    Future<void> open(WidgetTester t, {bool reduce = false}) async {
      await t.pumpWidget(
        _app(
          Builder(
            builder: (c) => CupertinoButton(
              onPressed: () => showAppSheet<void>(
                context: c,
                builder: (_) => Container(
                  key: const ValueKey('sheet'),
                  height: 400,
                  color: const Color(0xFFFFFFFF),
                ),
              ),
              child: const Text('open'),
            ),
          ),
          reduce: reduce,
        ),
      );
      await t.tap(find.text('open'));
    }

    testWidgets(
      'rises a little past its place and settles, with no gap under it',
      (t) async {
        await open(t);
        final screen = t.view.physicalSize.height / t.view.devicePixelRatio;
        var highestTop = double.infinity;
        for (var i = 0; i < 30; i++) {
          await t.pump(const Duration(milliseconds: 16));
          final top = t.getTopLeft(find.byKey(const ValueKey('sheet'))).dy;
          if (top < highestTop) highestTop = top;
          // Whatever the sheet does, its colour strip reaches the bottom of the screen.
          final fill = t.getRect(find.byKey(const ValueKey('sheet-fill')));
          final sheet = t.getRect(find.byKey(const ValueKey('sheet')));
          expect(fill.top, sheet.bottom);
          expect(fill.bottom, greaterThanOrEqualTo(screen - 0.01));
        }
        await t.pumpAndSettle();
        final rest = t.getTopLeft(find.byKey(const ValueKey('sheet'))).dy;
        expect(rest, screen - 400);
        expect(highestTop, lessThan(rest - 5)); // overshoot of about 3% (12 pt)
        expect(highestTop, greaterThan(rest - 20));
      },
    );

    testWidgets('with Reduce Motion it fades in place', (t) async {
      await open(t, reduce: true);
      await t.pump();
      await t.pump(const Duration(milliseconds: 100));
      final screen = t.view.physicalSize.height / t.view.devicePixelRatio;
      expect(
        t.getTopLeft(find.byKey(const ValueKey('sheet'))).dy,
        screen - 400,
      );
      final fade = t.widget<FadeTransition>(
        find
            .ancestor(
              of: find.byKey(const ValueKey('sheet')),
              matching: find.byType(FadeTransition),
            )
            .first,
      );
      expect(fade.opacity.value, inExclusiveRange(0, 1));
    });

    testWidgets('a tap on the dimmed area closes it', (t) async {
      await open(t);
      await t.pumpAndSettle();
      await t.tapAt(const Offset(20, 20));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('sheet')), findsNothing);
    });
  });

  group('tab pill', () {
    testWidgets('slides to the tapped tab, past it a little and back', (
      t,
    ) async {
      final h = Harness(signedIn: true);
      await t.pumpWidget(await h.build());
      await t.pumpAndSettle();
      final pill = find.byKey(const ValueKey('tab-pill'));
      double x() => t
          .getCenter(
            find
                .descendant(of: pill, matching: find.byType(DecoratedBox))
                .first,
          )
          .dx;
      final home = x();
      final bills = t.getCenter(find.text('Bills').last).dx;
      await t.tap(find.text('Bills').last);
      await t.pump();
      await t.pump(const Duration(milliseconds: 80));
      expect(x(), inExclusiveRange(home, bills));
      var furthest = 0.0;
      for (var i = 0; i < 30; i++) {
        await t.pump(const Duration(milliseconds: 16));
        if (x() > furthest) furthest = x();
      }
      await t.pumpAndSettle();
      expect(x(), closeTo(bills, 1));
      expect(furthest, greaterThan(bills + 1));
    });

    testWidgets('slides the other way in Arabic', (t) async {
      final h = Harness(signedIn: true);
      await t.pumpWidget(await h.build(prefs: {'locale': 'ar'}));
      await t.pumpAndSettle();
      final pill = find.byKey(const ValueKey('tab-pill'));
      double x() => t
          .getCenter(
            find
                .descendant(of: pill, matching: find.byType(DecoratedBox))
                .first,
          )
          .dx;
      final home = x();
      await t.tap(find.text('الفواتير').last);
      await t.pumpAndSettle();
      expect(x(), lessThan(home));
      expect(x(), closeTo(t.getCenter(find.text('الفواتير').last).dx, 1));
    });

    testWidgets('with Reduce Motion it does not slide', (t) async {
      final h = Harness(signedIn: true);
      await t.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: await h.build(),
        ),
      );
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('tab-pill')), findsNothing);
      expect(find.byType(AnimatedOpacity), findsWidgets);
    });
  });

  group('coins', () {
    test('hop up and fall back to rest, the second a moment later', () {
      expect(coinLift(0, 0), 0);
      expect(coinLift(1, 0), 0);
      expect(coinLift(1, 1), 0);
      expect(coinLift(0.2, 0), greaterThan(200));
      expect(coinLift(0.05, 1), 0);
    });

    testWidgets('play once on the logo; not with Reduce Motion', (t) async {
      List<double> lift() =>
          (t
                      .widget<CustomPaint>(
                        find.descendant(
                          of: find.byType(HalalaLogo),
                          matching: find.byType(CustomPaint),
                        ),
                      )
                      .painter!
                  as HalalaLogoPainter)
              .coinLift;
      await t.pumpWidget(_app(const HalalaLogo(dropCoins: true)));
      await t.pump(const Duration(milliseconds: 200));
      expect(lift()[0], greaterThan(0));
      await t.pumpAndSettle();
      expect(lift(), [0, 0]);

      await t.pumpWidget(const SizedBox());
      await t.pumpWidget(_app(const HalalaLogo(dropCoins: true), reduce: true));
      await t.pump(const Duration(milliseconds: 200));
      expect(lift(), [0, 0]);
    });
  });
}
