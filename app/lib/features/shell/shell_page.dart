import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/lock.dart';
import '../../core/widget_bridge.dart';
import '../../l10n/app_localizations.dart';
import '../home/home_page.dart';
import '../insights/insights_page.dart';
import '../insights/providers.dart';
import '../more/more_page.dart';
import '../obligations/obligations_page.dart';
import '../transactions/transactions_page.dart';

class ShellPage extends ConsumerStatefulWidget {
  const ShellPage({super.key});

  @override
  ConsumerState<ShellPage> createState() => _ShellPageState();
}

class _ShellPageState extends ConsumerState<ShellPage>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Coming back to the app refreshes the numbers the widget shows (the widget only knows what the app last saved).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(insightsProvider);
      ref.invalidate(todaySpendProvider);
      ref.invalidate(monthlyBudgetProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Every time the numbers change (opening the app, pull to refresh, a new budget) the widget gets them too.
    ref.listen(widgetSnapshotProvider, (_, next) {
      final snapshot = next.value;
      if (snapshot != null) {
        ref
            .read(widgetBridgeProvider)
            .save(snapshot, ref.read(clockProvider)());
      }
    });
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
