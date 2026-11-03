import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:spending_tracker/core/models.dart';
import 'package:spending_tracker/features/home/category_groups.dart';
import 'package:spending_tracker/features/insights/metrics.dart';
import 'package:spending_tracker/features/insights/widgets/donut_share.dart';
import 'package:spending_tracker/features/insights/widgets/insight_cards.dart';
import 'package:spending_tracker/features/insights/widgets/month_bars.dart';
import 'package:spending_tracker/features/insights/widgets/trend_chart.dart';
import 'package:spending_tracker/l10n/app_localizations.dart';

import 'support/fakes.dart';

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

final totals = [
  MonthTotal(DateTime.utc(2026, 8), 391200),
  MonthTotal(DateTime.utc(2026, 9), 524000),
  MonthTotal(DateTime.utc(2026, 10), 461000),
  MonthTotal(DateTime.utc(2026, 11), 481200),
];

void main() {
  for (final b in Brightness.values) {
    for (final lang in ['en', 'ar']) {
      testWidgets('charts render ($lang, ${b.name})', (tester) async {
        final ar = lang == 'ar';
        await pump(
          tester,
          Column(
            children: [
              TrendChart(
                thisMonth: const [0, 100, 300, 800],
                lastMonth: List.generate(30, (i) => i * 150),
                arabic: ar,
              ),
              MonthBars(totals: totals, budgetHalalas: 800000, arabic: ar),
              DonutShare(
                groups: const [
                  GroupSpend(CategoryGroup.food, 150000),
                  GroupSpend(CategoryGroup.transport, 50000),
                ],
                totalHalalas: 200000,
                arabic: ar,
              ),
            ],
          ),
          locale: Locale(lang),
          brightness: b,
        );
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('trend chart speaks both numbers', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(
      tester,
      const TrendChart(
        thisMonth: [0, 1000, 5000],
        lastMonth: [0, 500, 900, 4000, 9000],
        arabic: false,
      ),
    );
    expect(
      find.bySemanticsLabel(
        RegExp(r'SAR 50\.00 so far this month, SAR 9\.00 by the same day'),
      ),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('trend chart with no data at all does not crash', (tester) async {
    await pump(
      tester,
      const TrendChart(thisMonth: [], lastMonth: [], arabic: false),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('month bars: four labelled bars and the budget in the header', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pump(
      tester,
      MonthBars(totals: totals, budgetHalalas: 800000, arabic: false),
    );
    expect(
      find.bySemanticsLabel(RegExp(r'^(Aug|Sep|Oct|Nov): SAR')),
      findsNWidgets(4),
    );
    expect(find.bySemanticsLabel('Nov: SAR 4,812.00'), findsOneWidget);
    expect(find.text('Budget SAR 8,000.00'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('month bars: all zero and no budget still render', (
    tester,
  ) async {
    await pump(
      tester,
      MonthBars(
        totals: [
          for (var i = 0; i < 4; i++) MonthTotal(DateTime.utc(2026, 8 + i), 0),
        ],
        arabic: false,
      ),
    );
    expect(find.textContaining('Budget'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('donut: legend shows shares of the whole month', (tester) async {
    await pump(
      tester,
      const DonutShare(
        groups: [
          GroupSpend(CategoryGroup.food, 150000),
          GroupSpend(CategoryGroup.transport, 50000),
        ],
        totalHalalas: 200000,
        arabic: false,
      ),
    );
    expect(find.text('Food'), findsOneWidget);
    expect(find.text('75%'), findsOneWidget);
    expect(find.text('25%'), findsOneWidget);
    expect(find.text('2,000'), findsOneWidget); // the ring's centre
  });

  testWidgets('donut: no groups is an empty ring, not a crash', (tester) async {
    await pump(
      tester,
      const DonutShare(groups: [], totalHalalas: 0, arabic: false),
    );
    expect(tester.takeException(), isNull);
  });

  for (final lang in ['en', 'ar']) {
    testWidgets(
      'the whole Insights page survives 2x text on a 360pt phone ($lang)',
      (tester) async {
        tester.view.physicalSize = const Size(720, 8000);
        tester.view.devicePixelRatio = 2;
        tester.platformDispatcher.textScaleFactorTestValue = 2.0;
        addTearDown(() {
          tester.view.reset();
          tester.platformDispatcher.clearAllTestValues();
        });
        Txn t(
          String id,
          String utc,
          int h, {
          String? cat,
          String m = 'A long merchant name for the list',
        }) => Txn(
          id: id,
          type: 'purchase',
          direction: 'out',
          amountHalalas: h,
          occurredAt: DateTime.parse('${utc}Z'),
          merchant: m,
          merchantNorm: m.toLowerCase(),
          categoryId: cat,
        );
        final h = Harness(signedIn: true)
          ..data.monthlyBudget = 150000000
          ..data.history = [
            t('1', '2026-10-05T09:00:00', 123456789, cat: 'c-din'),
            t(
              '2',
              '2026-10-06T09:00:00',
              99999999,
              cat: 'c-gro',
              m: 'Other shop',
            ),
            t('3', '2026-09-06T09:00:00', 5000, cat: 'c-gro', m: 'Other shop'),
          ];
        await tester.pumpWidget(await h.build(prefs: {'locale': lang}));
        await tester.pumpAndSettle();
        await tester.tap(
          find.text(lang == 'ar' ? 'التحليلات' : 'Insights').last,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('a short amount leaves most of the row to the name', (
    tester,
  ) async {
    await pump(
      tester,
      const InsightLine(
        title: 'A fairly long merchant name that needs room',
        amount: 'SAR 1.00',
      ),
    );
    final name = tester.getSize(
      find.text('A fairly long merchant name that needs room'),
    );
    final row = tester.getSize(find.byType(InsightLine));
    expect(name.width, greaterThan(row.width * 0.6));
  });

  testWidgets('the donut speaks its total and lists every group', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pump(
      tester,
      DonutShare(
        groups: [
          for (final g in CategoryGroup.values.take(7)) GroupSpend(g, 1000),
        ],
        totalHalalas: 7000,
        arabic: false,
      ),
    );
    expect(find.bySemanticsLabel('Where it goes: SAR 70.00'), findsOneWidget);
    expect(
      find.textContaining('%'),
      findsNWidgets(7),
    ); // the legend is not cut at five
    handle.dispose();
  });
}
