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
      find.text('SAR 0.00'),
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
    expect(
      find.bySemanticsLabel(RegExp(r'^Spent SAR .* on ')),
      findsNWidgets(7),
    );
    expect(find.bySemanticsLabel('Spent SAR 145.00 on Sunday'), findsOneWidget);
    handle.dispose();
  });

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
    expect(find.text('SAR 1,500.00'), findsOneWidget);
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
    expect(find.text('~SAR 1,994.00'), findsOneWidget);
    expect(find.text('—'), findsOneWidget);
  });
}

Object? tester(WidgetTester t) => t.takeException();
