import 'package:flutter/cupertino.dart';

import '../../ui/confirm_sheet.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../account/account_providers.dart';
import '../../core/capture_bridge.dart';
import '../../core/capture_setup.dart';
import '../../core/lock.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/reminder_bridge.dart';
import '../../core/reminders.dart';
import '../../core/widget_bridge.dart';
import '../../core/widget_setup.dart';

import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../l10n/app_localizations.dart';
import '../../ui/pill_tab_bar.dart';
import '../../ui/tokens.dart';
import 'tabs.dart';
import '../home/home_page.dart';
import '../insights/insights_page.dart';
import '../insights/providers.dart';
import '../obligations/providers.dart';
import '../more/more_page.dart';
import '../more/shortcut_guide.dart';
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
    // The flag may already be set when the shell first builds (sign-in redirects before it is read).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _showReactivated();
    });
    _startUp();
  }

  /// A sign-in whose reactivation call failed (offline) would leave the deletion standing: ask again, and only then
  /// set up capture (the token service refuses accounts with a pending deletion).
  Future<void> _startUp() async {
    final was = await ref.read(authRepositoryProvider).reactivateIfPending();
    if (!mounted) return;
    if (was) ref.read(accountReactivatedProvider.notifier).set(true);
    _syncCapture();
    await _offerShortcutGuide();
  }

  /// A new account (nothing has ever been sent from this phone) is shown the step-by-step Shortcuts guide once, with a
  /// Skip button. An account that already sends messages, and any account after the first time, is left alone.
  Future<void> _offerShortcutGuide() async {
    final bridge = ref.read(captureBridgeProvider);
    if (!bridge.hasShortcuts) return;
    final uid = ref.read(authRepositoryProvider).userId;
    final prefs = ref.read(sharedPrefsProvider);
    final key = shortcutGuideSeenKey(uid);
    if (uid == null || prefs.getBool(key) == true) return;
    final status = await bridge.status();
    if (!mounted) return;
    await prefs.setBool(key, true);
    if (status.last.isNotEmpty || !mounted) return;
    await showShortcutGuide(context, offer: true);
  }

  /// A sign-in that just cancelled a pending account deletion tells the person once.
  void _showReactivated() {
    if (!ref.read(accountReactivatedProvider)) return;
    ref.read(accountReactivatedProvider.notifier).set(false);
    final t = AppLocalizations.of(context);
    showNoticeSheet(
      context,
      title: t.reactivatedTitle,
      message: t.reactivatedBody,
      okLabel: t.reactivatedOk,
    );
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
    ref.listen(accountReactivatedProvider, (_, on) {
      if (on) _showReactivated();
    });
    return CupertinoTabScaffold(
      controller: ref.watch(tabControllerProvider),
      backgroundColor: AppTokens.bg.resolveFrom(context),
      tabBar: PillTabBar(
        items: [
          BottomNavigationBarItem(
            icon: const Icon(LucideIcons.house),
            label: t.tabHome,
          ),
          BottomNavigationBarItem(
            icon: const Icon(LucideIcons.list),
            label: t.tabTransactions,
          ),
          BottomNavigationBarItem(
            icon: const Icon(LucideIcons.receiptText),
            label: t.tabObligations,
          ),
          BottomNavigationBarItem(
            icon: const Icon(LucideIcons.chartNoAxesColumn),
            label: t.tabInsights,
          ),
          BottomNavigationBarItem(
            icon: const Icon(LucideIcons.ellipsis),
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
