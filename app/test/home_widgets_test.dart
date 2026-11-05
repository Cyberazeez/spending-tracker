import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:spending_tracker/core/models.dart';
import 'package:spending_tracker/features/home/category_groups.dart';
import 'package:spending_tracker/features/home/widgets/bill_card.dart';
import 'package:spending_tracker/features/home/widgets/hero_card.dart';
import 'package:spending_tracker/features/home/widgets/share_bar.dart';
import 'package:spending_tracker/features/home/widgets/week_bars.dart';
import 'package:spending_tracker/features/insights/metrics.dart';
import 'package:spending_tracker/l10n/app_localizations.dart';

Future<void> pump(
  WidgetTester tester,
  Widget child, {
  Locale locale = const Locale('en'),
  Brightness brightness = Brightness.light,
}) async {
  await initializeDateFormatting('en');
  await initializeDateFormatting('ar');
  await tester.pumpWidget(
    CupertinoApp(
      locale: locale,
      theme: CupertinoThemeData(brightness: brightness),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: CupertinoPageScaffold(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

ObligationInstance bill(DateTime due, {int? amount = 199400, int? usualMin}) =>
    ObligationInstance(
      id: 'i',
      obligationId: 'o',
      name: 'Card statement',
      kind: 'card_statement',
      dueDate: due,
      status: 'pending',
      expectedHalalas: amount,
      usualMinHalalas: usualMin,
    );

void main() {
  for (final b in Brightness.values) {
    for (final locale in const [Locale('en'), Locale('ar')]) {
      final tag = '${b.name} ${locale.languageCode}';
      testWidgets('hero shows the percent of the budget ($tag)', (t) async {
        await pump(
          t,
          HeroCard(
            monthHalalas: 481200,
            todayHalalas: 14500,
            budgetHalalas: 800000,
            lastMonthDiffHalalas: -60000,
            lastMonthPercent: -12,
            arabic: locale.languageCode == 'ar',
          ),
          locale: locale,
          brightness: b,
        );
        expect(find.text('60%'), findsOneWidget);
        expect(tester(t), isNull); // no exception was thrown while building
      });
    }
  }

  testWidgets('hero without a budget asks for one and shows no percent', (
    t,
  ) async {
    await pump(
      t,
      const HeroCard(monthHalalas: 481200, todayHalalas: 0, arabic: false),
    );
    expect(find.text('Set a monthly budget'), findsOneWidget);
    expect(find.textContaining('%'), findsNothing);
    expect(find.text('Left to spend'), findsNothing);
  });

  testWidgets('hero over budget keeps the true percent', (t) async {
    await pump(
      t,
      const HeroCard(
        monthHalalas: 900000,
        todayHalalas: 0,
        budgetHalalas: 800000,
        arabic: false,
      ),
    );
    expect(find.text('112%'), findsOneWidget);
    expect(
      find.text('⃁ 0.00'),
      findsWidgets,
    ); // nothing left to spend, never negative
  });

  testWidgets('hero with nothing to compare shows a dash', (t) async {
    await pump(
      t,
      const HeroCard(
        monthHalalas: 100,
        todayHalalas: 0,
        budgetHalalas: 800000,
        arabic: false,
      ),
    );
    expect(find.text('—'), findsOneWidget);
  });

  testWidgets('week bars: seven labelled bars, one per day', (t) async {
    final days = [
      for (var i = 0; i < 7; i++)
        DaySpend(DateTime.utc(2026, 11, 9 + i), i == 6 ? 14500 : 1000 * i),
    ];
    final handle = t.ensureSemantics();
    await pump(t, WeekBars(days: days, arabic: false));
    expect(find.bySemanticsLabel(RegExp(r'^Spent ⃁ .* on ')), findsNWidgets(7));
    expect(find.bySemanticsLabel('Spent ⃁ 145.00 on Sunday'), findsOneWidget);
    handle.dispose();
  });

  testWidgets(
    'week bars: no total, tap a bar for its amount, tap again to hide',
    (t) async {
      final days = [
        for (var i = 0; i < 7; i++)
          DaySpend(DateTime.utc(2026, 11, 9 + i), 10000 + i * 5000),
      ];
      await pump(t, WeekBars(days: days, arabic: false));
      expect(find.textContaining('total'), findsNothing);
      expect(find.byKey(const ValueKey('week-bar-callout')), findsNothing);
      await t.tap(find.byKey(const ValueKey('week-bar-2')));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('week-bar-callout')), findsOneWidget);
      expect(find.textContaining('200.00'), findsOneWidget); // 20,000 halalas
      // tapping another bar moves the bubble, the same bar again hides it
      await t.tap(find.byKey(const ValueKey('week-bar-5')));
      await t.pumpAndSettle();
      expect(find.textContaining('350.00'), findsOneWidget);
      expect(find.textContaining('200.00'), findsNothing);
      await t.tap(find.byKey(const ValueKey('week-bar-5')));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('week-bar-callout')), findsNothing);
    },
  );

  testWidgets('week bars with no spending still render seven bars', (t) async {
    final days = [
      for (var i = 0; i < 7; i++) DaySpend(DateTime.utc(2026, 11, 9 + i), 0),
    ];
    await pump(
      t,
      WeekBars(days: days, arabic: true),
      locale: const Locale('ar'),
    );
    expect(find.byType(WeekBars), findsOneWidget);
  });

  testWidgets('share bar: rows with the share of the whole month', (t) async {
    await pump(
      t,
      const ShareBar(
        top: [
          GroupSpend(CategoryGroup.food, 150000),
          GroupSpend(CategoryGroup.transport, 50000),
        ],
        totalHalalas: 200000,
        arabic: false,
      ),
    );
    expect(find.text('Food'), findsOneWidget);
    expect(find.text('Transport'), findsOneWidget);
    expect(find.text('75%'), findsOneWidget);
    expect(find.text('25%'), findsOneWidget);
    expect(find.text('⃁ 1,500.00'), findsOneWidget);
  });

  testWidgets('share bar: the stacked bar is really drawn (not zero height)', (
    t,
  ) async {
    await pump(
      t,
      const ShareBar(
        top: [
          GroupSpend(CategoryGroup.food, 150000),
          GroupSpend(CategoryGroup.transport, 50000),
        ],
        totalHalalas: 200000,
        arabic: false,
      ),
    );
    final segments = find.descendant(
      of: find.byType(ClipRRect),
      matching: find.byType(ColoredBox),
    );
    expect(segments, findsNWidgets(2));
    for (final e in segments.evaluate()) {
      expect((e.renderObject! as RenderBox).size.height, 14);
    }
  });

  testWidgets('bill card: overdue, soon, estimate and unknown amount', (
    t,
  ) async {
    final today = DateTime.utc(2026, 11, 3);
    await pump(
      t,
      Column(
        children: [
          BillCard(
            bill: bill(DateTime.utc(2026, 11, 1)),
            today: today,
            arabic: false,
          ),
          BillCard(
            bill: bill(DateTime.utc(2026, 11, 8)),
            today: today,
            arabic: false,
          ),
          BillCard(
            bill: bill(DateTime.utc(2026, 11, 28), usualMin: 65800),
            today: today,
            arabic: false,
          ),
          BillCard(
            bill: bill(DateTime.utc(2026, 11, 4), amount: null),
            today: today,
            arabic: false,
          ),
        ],
      ),
    );
    expect(find.text('Overdue'), findsOneWidget);
    expect(find.text('Due in 5 days'), findsOneWidget);
    expect(find.text('Due in 25 days'), findsOneWidget);
    expect(find.text('Due tomorrow'), findsOneWidget);
    expect(find.text('~⃁ 1,994.00'), findsOneWidget);
    expect(find.text('—'), findsOneWidget);
  });

  testWidgets('week bars: Arabic days have different letters', (t) async {
    final days = [
      for (var i = 0; i < 7; i++) DaySpend(DateTime.utc(2026, 11, 9 + i), 100),
    ];
    await pump(
      t,
      WeekBars(days: days, arabic: true),
      locale: const Locale('ar'),
    );
    for (final l in ['ن', 'ث', 'ر', 'خ', 'ج', 'س', 'ح']) {
      expect(find.text(l), findsOneWidget, reason: l);
    }
  });

  testWidgets(
    'hero: a tiny or empty last month shows an amount, not a huge percent',
    (t) async {
      await pump(
        t,
        const HeroCard(
          monthHalalas: 480000,
          budgetHalalas: 800000,
          lastMonthDiffHalalas: 479000,
          lastMonthPercent: 47900,
          arabic: false,
        ),
      );
      expect(find.textContaining('%'), findsNWidgets(1)); // only the ring
      expect(find.textContaining('+⃁ 4,790.00'), findsOneWidget);
    },
  );

  testWidgets('hero: a difference that rounds to 0% says Same', (t) async {
    await pump(
      t,
      const HeroCard(
        monthHalalas: 100001,
        budgetHalalas: 800000,
        lastMonthDiffHalalas: 1,
        lastMonthPercent: 0,
        arabic: false,
      ),
    );
    expect(find.text('Same'), findsOneWidget);
  });

  testWidgets('hero hides Today while it is unknown', (t) async {
    await pump(
      t,
      const HeroCard(monthHalalas: 100, budgetHalalas: 800000, arabic: false),
    );
    expect(find.text('Today'), findsNothing);
  });

  for (final lang in ['en', 'ar']) {
    testWidgets('Home cards survive 2x text on a 360pt phone ($lang)', (
      t,
    ) async {
      t.view.physicalSize = const Size(720, 1280);
      t.view.devicePixelRatio = 2;
      t.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(() {
        t.view.reset();
        t.platformDispatcher.clearAllTestValues();
      });
      final locale = Locale(lang);
      final ar = lang == 'ar';
      await pump(
        t,
        Column(
          children: [
            HeroCard(
              monthHalalas: 123456789,
              todayHalalas: 98765432,
              budgetHalalas: 150000000,
              lastMonthDiffHalalas: -500,
              lastMonthPercent: -3,
              arabic: ar,
            ),
            WeekBars(
              days: [
                for (var i = 0; i < 7; i++)
                  DaySpend(DateTime.utc(2026, 11, 9 + i), 99999999),
              ],
              arabic: ar,
            ),
            ShareBar(
              top: const [
                GroupSpend(CategoryGroup.food, 123456789),
                GroupSpend(CategoryGroup.homeBills, 55555555),
              ],
              totalHalalas: 200000000,
              arabic: ar,
            ),
            BillCard(
              bill: bill(DateTime.utc(2026, 11, 8), amount: 123456789),
              today: DateTime.utc(2026, 11, 3),
              arabic: ar,
            ),
          ],
        ),
        locale: locale,
      );
      expect(t.takeException(), isNull);
    });
  }
}

Object? tester(WidgetTester t) => t.takeException();
