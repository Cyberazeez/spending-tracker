import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/features/auth/lock_page.dart';
import 'package:spending_tracker/features/obligations/widgets/bills_widgets.dart';
import 'package:spending_tracker/l10n/app_localizations.dart';
import 'package:spending_tracker/ui/grow_in.dart';
import 'package:spending_tracker/ui/press.dart';
import 'package:spending_tracker/ui/settings_group.dart';

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
    child: Center(child: SizedBox(width: 340, child: child)),
  ),
);

Offset _shift(WidgetTester t, Finder of) {
  final tr = t.widget<Transform>(
    find
        .descendant(
          of: find.descendant(of: of, matching: find.byType(Pressable)),
          matching: find.byType(Transform),
        )
        .first,
  );
  final v = tr.transform.getTranslation();
  return Offset(v.x, v.y);
}

void main() {
  testWidgets('pill segments: the emerald pill slides to the tapped segment', (
    t,
  ) async {
    var value = 'a';
    await t.pumpWidget(
      _app(
        StatefulBuilder(
          builder: (_, set) => PillSegments<String>(
            value: value,
            labels: const {'a': 'One', 'b': 'Two', 'c': 'Three'},
            onChanged: (v) => set(() => value = v),
          ),
        ),
      ),
    );
    double x() => t.getCenter(find.byKey(const ValueKey('segment-pill'))).dx;
    final start = x();
    final target = t.getCenter(find.text('Three')).dx;
    expect(start, closeTo(t.getCenter(find.text('One')).dx, 1));
    await t.tap(find.text('Three'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
    expect(x(), inExclusiveRange(start, target));
    await t.pumpAndSettle();
    expect(x(), closeTo(target, 1));
  });

  testWidgets('pill segments with Reduce Motion fade instead of sliding', (
    t,
  ) async {
    await t.pumpWidget(
      _app(
        PillSegments<String>(
          value: 'b',
          labels: const {'a': 'One', 'b': 'Two'},
          onChanged: (_) {},
        ),
        reduce: true,
      ),
    );
    expect(find.byKey(const ValueKey('sliding-pill')), findsNothing);
    expect(find.byType(AnimatedOpacity), findsNWidgets(2));
  });

  testWidgets('a switch sits on a hard shadow and presses into it', (t) async {
    await t.pumpWidget(
      _app(
        Builder(builder: (c) => appSwitch(c, value: true, onChanged: (_) {})),
      ),
    );
    expect(find.byKey(const ValueKey('switch-shadow')), findsOneWidget);
    final g = await t.startGesture(t.getCenter(find.byType(CupertinoSwitch)));
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
    expect(_shift(t, find.byType(CupertinoPageScaffold)), const Offset(2, 3));
    await g.up();
    await t.pumpAndSettle();
  });

  testWidgets('a chip gets a small shadow and presses into it', (t) async {
    await t.pumpWidget(
      _app(
        CupertinoButton(
          onPressed: () {},
          child: const PressShadow(
            decoration: BoxDecoration(color: Color(0xFFFFFFFF)),
            child: Text('Chip'),
          ),
        ),
      ),
    );
    final deco = t.widget<DecoratedBox>(
      find
          .ancestor(of: find.text('Chip'), matching: find.byType(DecoratedBox))
          .first,
    );
    expect(
      (deco.decoration as BoxDecoration).boxShadow!.first.offset,
      const Offset(2, 3),
    );
    final g = await t.startGesture(t.getCenter(find.text('Chip')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
    expect(_shift(t, find.byType(CupertinoPageScaffold)), const Offset(2, 3));
    await g.up();
    await t.pumpAndSettle();
  });

  testWidgets('a settings row lights up while held', (t) async {
    await t.pumpWidget(
      _app(
        SettingsGroup(
          children: [
            SettingsRow(
              icon: CupertinoIcons.delete,
              color: const Color(0xFFFF9DB0),
              title: 'Delete my account',
              danger: true,
              onTap: () {},
            ),
          ],
        ),
      ),
    );
    Color fill() =>
        ((t.widget<AnimatedContainer>(find.byType(AnimatedContainer)).decoration
                as BoxDecoration)
            .color ??
        const Color(0x00000000));
    expect(fill().a, 0);
    final g = await t.startGesture(t.getCenter(find.text('Delete my account')));
    await t.pump();
    expect(fill().a, greaterThan(0.9));
    await g.up();
    await t.pumpAndSettle();
    expect(fill().a, 0);
  });

  group('lock screen', () {
    testWidgets('asks for Face ID once the coins have landed', (t) async {
      final h = Harness(signedIn: true)..authenticator.result = false;
      await t.pumpWidget(await h.build());
      await t.pump();
      await t.pump(const Duration(milliseconds: 500));
      expect(find.byType(LockPage), findsOneWidget);
      expect(h.authenticator.calls, 0);
      await t.pump(lockPromptDelay);
      expect(h.authenticator.calls, 1);
      await t.pumpAndSettle();
      expect(h.authenticator.calls, 1);
    });

    testWidgets('left before the prompt, it asks when the app is back', (
      t,
    ) async {
      final h = Harness(signedIn: true)..authenticator.result = false;
      await t.pumpWidget(await h.build());
      await t.pump();
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await t.pump(lockPromptDelay + const Duration(milliseconds: 100));
      expect(h.authenticator.calls, 0);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await t.pump();
      expect(h.authenticator.calls, greaterThanOrEqualTo(1));
    });

    testWidgets('with Reduce Motion it asks straight away', (t) async {
      final h = Harness(signedIn: true)..authenticator.result = false;
      await t.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: await h.build(),
        ),
      );
      await t.pump();
      await t.pump();
      expect(h.authenticator.calls, 1);
    });
  });

  group('grow in', () {
    Widget host(bool shown) => _app(
      TickerMode(
        enabled: shown,
        child: GrowIn(
          builder: (_, g) =>
              Text('${(g * 100).round()}', textDirection: TextDirection.ltr),
        ),
      ),
    );

    testWidgets('fills from empty, overshoots a little, settles at full', (
      t,
    ) async {
      await t.pumpWidget(host(true));
      expect(find.text('0'), findsOneWidget);
      var peak = 0;
      for (var i = 0; i < 60; i++) {
        await t.pump(const Duration(milliseconds: 16));
        final v = int.parse(t.widget<Text>(find.byType(Text).last).data!);
        if (v > peak) peak = v;
      }
      await t.pumpAndSettle();
      expect(find.text('100'), findsOneWidget);
      expect(peak, greaterThan(100));
    });

    testWidgets('plays again when its screen comes back into view', (t) async {
      await t.pumpWidget(host(true));
      await t.pumpAndSettle();
      await t.pumpWidget(host(false));
      await t.pump();
      await t.pumpWidget(host(true));
      await t.pump();
      await t.pump(const Duration(milliseconds: 100));
      final v = int.parse(t.widget<Text>(find.byType(Text).last).data!);
      expect(v, lessThan(100));
      await t.pumpAndSettle();
      expect(find.text('100'), findsOneWidget);
    });

    testWidgets('with Reduce Motion shows the value at once', (t) async {
      await t.pumpWidget(
        _app(
          GrowIn(builder: (_, g) => Text('${(g * 100).round()}')),
          reduce: true,
        ),
      );
      await t.pump();
      expect(find.text('100'), findsOneWidget);
    });
  });
}
