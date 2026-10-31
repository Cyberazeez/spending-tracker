import 'package:flutter/cupertino.dart';

import '../../l10n/app_localizations.dart';
import '../../ui/empty_state.dart';
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
            0 => _Placeholder(
              title: t.tabHome,
              icon: CupertinoIcons.tray,
              heading: t.emptyHomeTitle,
              body: t.emptyHomeBody,
            ),
            1 => const TransactionsPage(),
            2 => const ObligationsPage(),
            3 => _Placeholder(
              title: t.tabInsights,
              icon: CupertinoIcons.chart_pie,
              heading: t.comingSoon,
            ),
            _ => const MorePage(),
          },
        );
      },
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({
    required this.title,
    required this.icon,
    required this.heading,
    this.body,
  });

  final String title;
  final IconData icon;
  final String heading;
  final String? body;

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    navigationBar: CupertinoNavigationBar(middle: Text(title)),
    child: SafeArea(
      child: EmptyState(icon: icon, title: heading, body: body),
    ),
  );
}
