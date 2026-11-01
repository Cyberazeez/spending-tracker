import 'package:flutter/cupertino.dart';

import '../../l10n/app_localizations.dart';
import '../home/home_page.dart';
import '../insights/insights_page.dart';
import '../more/more_page.dart';
import '../obligations/obligations_page.dart';
import '../transactions/transactions_page.dart';

class ShellPage extends StatelessWidget {
  const ShellPage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return CupertinoTabScaffold(
      tabBar: CupertinoTabBar(
        items: [
          BottomNavigationBarItem(
            icon: const Icon(CupertinoIcons.house),
            label: t.tabHome,
          ),
          BottomNavigationBarItem(
            icon: const Icon(CupertinoIcons.list_bullet),
            label: t.tabTransactions,
          ),
          BottomNavigationBarItem(
            icon: const Icon(CupertinoIcons.calendar),
            label: t.tabObligations,
          ),
          BottomNavigationBarItem(
            icon: const Icon(CupertinoIcons.chart_pie),
            label: t.tabInsights,
          ),
          BottomNavigationBarItem(
            icon: const Icon(CupertinoIcons.ellipsis),
            label: t.tabMore,
          ),
        ],
      ),
      tabBuilder: (context, index) {
        return CupertinoTabView(
          builder: (context) => switch (index) {
            0 => const HomePage(),
            1 => const TransactionsPage(),
            2 => const ObligationsPage(),
            3 => const InsightsPage(),
            _ => const MorePage(),
          },
        );
      },
    );
  }
}
