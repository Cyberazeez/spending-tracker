import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/capture_bridge.dart';
import '../../core/capture_setup.dart';
import '../../core/lock.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/reminder_bridge.dart';
import '../../core/reminders.dart';
import '../../core/widget_bridge.dart';
import '../../core/widget_setup.dart';
import '../../l10n/app_localizations.dart';
import '../home/home_page.dart';
import '../insights/insights_page.dart';
import '../insights/providers.dart';
import '../obligations/providers.dart';
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
    _syncCapture();
  }

  /// Gives the "Add bank message" Shortcuts action its token (once) and sends anything it queued offline.
  void _syncCapture() {
    ensureWidgetReady(
      ref.read(widgetBridgeProvider),
      ref.read(tokenRepositoryProvider),
      () => ref.read(authRepositoryProvider).userId,
    );
    ensureCaptureReady(
      ref.read(captureBridgeProvider),
      ref.read(tokenRepositoryProvider),
      () => ref.read(authRepositoryProvider).userId,
    );
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
      _syncCapture();
      ref.invalidate(insightsProvider);
      ref.invalidate(todaySpendProvider);
      ref.invalidate(monthlyBudgetProvider);
      ref.invalidate(obligationsProvider);
    }
  }

  /// Schedules (or clears) the bill reminders to match the current obligations, the switch and the language.
  void _syncReminders(List<ObligationInstance>? instances) {
    final bridge = ref.read(reminderBridgeProvider);
    if (!ref.read(remindersEnabledProvider)) return;
    if (instances == null) return;
    bridge.replace(
      reminderItems(
        instances,
        ref.read(clockProvider)(),
        ref.read(localeProvider).languageCode,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(obligationsProvider, (_, next) => _syncReminders(next.value));
    ref.listen(remindersEnabledProvider, (_, on) {
      if (on) _syncReminders(ref.read(obligationsProvider).value);
    });
    ref.listen(localeProvider, (_, _) {
      _syncReminders(ref.read(obligationsProvider).value);
    });
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
