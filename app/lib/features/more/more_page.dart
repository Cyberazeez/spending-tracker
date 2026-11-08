import 'package:flutter/cupertino.dart';

import 'capture_label.dart';

import '../../ui/confirm_sheet.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/capture_bridge.dart';
import '../../core/capture_setup.dart';
import '../../core/format.dart' show ltrIsolate;
import '../../core/lock.dart';
import '../../core/money.dart';
import '../../core/providers.dart';
import '../../core/reminders.dart';
import '../../core/widget_bridge.dart';
import '../../core/widget_setup.dart';
import '../../l10n/app_localizations.dart';
import '../../router.dart';
import '../account/account_pages.dart';
import '../ai/providers.dart';
import '../insights/budget_flow.dart';
import '../insights/providers.dart' show monthlyBudgetProvider;
import '../../ui/bottom_inset.dart';
import '../../ui/choice_sheet.dart';
import '../../ui/settings_group.dart';
import '../../ui/tokens.dart';

class MorePage extends ConsumerWidget {
  const MorePage({super.key});

  Future<void> _pickLanguage(BuildContext context, WidgetRef ref) async {
    final t = AppLocalizations.of(context);
    final current = ref.read(localeProvider).languageCode;
    final choice = await showChoiceSheet<String>(
      context,
      title: t.language,
      options: [
        ChoiceOption(
          value: 'en',
          label: t.languageEnglish,
          icon: LucideIcons.globe,
          selected: current == 'en',
        ),
        ChoiceOption(
          value: 'ar',
          label: t.languageArabic,
          icon: LucideIcons.languages,
          selected: current == 'ar',
        ),
      ],
    );
    if (choice != null) await ref.read(localeProvider.notifier).set(choice);
  }

  Future<void> _toggleReminders(
    BuildContext context,
    WidgetRef ref,
    bool on,
  ) async {
    final controller = ref.read(remindersEnabledProvider.notifier);
    if (!on) {
      await controller.disable();
      return;
    }
    final t = AppLocalizations.of(context);
    final granted = await controller.enable();
    if (granted || !context.mounted) return;
    await showNoticeSheet(context, title: t.remindersDenied);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final locale = ref.watch(localeProvider);
    ref.watch(accountRevisionProvider);
    final auth = ref.read(authRepositoryProvider);
    final account = auth.displayName ?? auth.email;
    return CupertinoPageScaffold(
      backgroundColor: AppTokens.bg.resolveFrom(context),
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: Text(t.tabMore),
            backgroundColor: AppTokens.bg.resolveFrom(context),
            border: null,
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            sliver: SliverList.list(
              children: [
                SettingsGroup(
                  children: [
                    SettingsRow(
                      icon: LucideIcons.globe,
                      color: const Color(0xFF6C8CFF),
                      title: t.language,
                      value: locale.languageCode == 'ar'
                          ? t.languageArabic
                          : t.languageEnglish,
                      onTap: () => _pickLanguage(context, ref),
                    ),
                    SettingsRow(
                      icon: LucideIcons.bell,
                      color: const Color(0xFFFFB340),
                      title: t.remindersTitle,
                      subtitle: t.remindersHelp,
                      control: CupertinoSwitch(
                        value: ref.watch(remindersEnabledProvider),
                        activeTrackColor: AppTokens.accent.resolveFrom(context),
                        onChanged: (on) => _toggleReminders(context, ref, on),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SettingsGroup(
                  children: [
                    const _AiRow(),
                    // Only paying accounts: AI reading of unknown banks needs the paid plan.
                    if (ref.watch(aiAllowedProvider).value == true)
                      const _AiParseRow(),
                  ],
                ),
                const SizedBox(height: 16),
                SettingsGroup(
                  children: [
                    const _BudgetRow(),
                    const _CaptureStatusRow(),
                    SettingsRow(
                      icon: LucideIcons.user,
                      color: const Color(0xFF6C8CFF),
                      title: t.moreAccount,
                      subtitle: account,
                      onTap: () => context.push(accountPath),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SettingsGroup(
                  children: [
                    SettingsRow(
                      icon: LucideIcons.logOut,
                      color: AppTokens.danger.resolveFrom(context),
                      title: t.signOut,
                      danger: true,
                      onTap: () async {
                        await releaseCapture(
                          ref.read(captureBridgeProvider),
                          ref.read(tokenRepositoryProvider),
                        );
                        await releaseWidget(
                          ref.read(widgetBridgeProvider),
                          ref.read(tokenRepositoryProvider),
                        );
                        await ref.read(authRepositoryProvider).signOut();
                        ref.read(lockProvider.notifier).lockNow();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          const BottomInset(),
        ],
      ),
    );
  }
}

/// The AI switch. Off by default; the server also refuses any AI call while it is off.
class _AiRow extends ConsumerStatefulWidget {
  const _AiRow();

  @override
  ConsumerState<_AiRow> createState() => _AiRowState();
}

class _AiRowState extends ConsumerState<_AiRow> {
  bool? _pending; // the value the user just picked, until the save is confirmed

  Future<void> _set(bool on) async {
    if (_pending != null) return; // one save at a time
    setState(() => _pending = on);
    final t = AppLocalizations.of(context);
    var failed = false;
    try {
      await ref.read(dataRepositoryProvider).setAiEnabled(on);
    } catch (_) {
      failed = true;
    }
    if (!mounted) return;
    ref.invalidate(aiEnabledProvider);
    await ref.read(aiEnabledProvider.future).catchError((_) => false);
    if (!mounted) return;
    setState(() => _pending = null);
    if (failed) {
      await showNoticeSheet(context, title: t.obSaveFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final stored = ref.watch(aiEnabledProvider).value ?? false;
    // Not on the paid plan: no switch, only a note. The server refuses AI for these accounts anyway.
    if (ref.watch(aiAllowedProvider).value == false) {
      return SettingsRow(
        icon: LucideIcons.sparkles,
        color: const Color(0xFF3CC4A8),
        title: t.aiTitle,
        subtitle: t.aiPaidOnly,
      );
    }
    return SettingsRow(
      icon: LucideIcons.sparkles,
      color: const Color(0xFF3CC4A8),
      title: t.aiTitle,
      subtitle: t.aiSubtitle,
      control: CupertinoSwitch(
        value: _pending ?? stored,
        activeTrackColor: AppTokens.accent.resolveFrom(context),
        onChanged: _set,
      ),
    );
  }
}

/// Consent for AI reading of messages from banks the app has no parser for. Off by default; turning it on asks first,
/// because (unlike the assistant) it sends the text of one message, with numbers and names removed.
class _AiParseRow extends ConsumerStatefulWidget {
  const _AiParseRow();

  @override
  ConsumerState<_AiParseRow> createState() => _AiParseRowState();
}

class _AiParseRowState extends ConsumerState<_AiParseRow> {
  bool? _pending;

  Future<void> _set(bool on) async {
    if (_pending != null) return;
    final t = AppLocalizations.of(context);
    if (on) {
      final ok = await showConfirmSheet(
        context,
        title: t.aiParseAskTitle,
        message: t.aiParseAskBody,
        confirmLabel: t.aiParseAskConfirm,
      );
      if (ok != true || !mounted) return;
    }
    setState(() => _pending = on);
    var failed = false;
    try {
      await ref.read(dataRepositoryProvider).setAiParseEnabled(on);
    } catch (_) {
      failed = true;
    }
    if (!mounted) return;
    ref.invalidate(aiParseEnabledProvider);
    await ref.read(aiParseEnabledProvider.future).catchError((_) => false);
    if (!mounted) return;
    setState(() => _pending = null);
    if (failed) await showNoticeSheet(context, title: t.obSaveFailed);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final stored = ref.watch(aiParseEnabledProvider).value ?? false;
    return SettingsRow(
      icon: LucideIcons.scanText,
      color: const Color(0xFF6C8CFF),
      title: t.aiParseTitle,
      subtitle: t.aiParseSubtitle,
      control: CupertinoSwitch(
        value: _pending ?? stored,
        activeTrackColor: AppTokens.accent.resolveFrom(context),
        onChanged: _set,
      ),
    );
  }
}

/// Shows what the "Add bank message" Shortcuts action has queued and how the last send went.
/// The monthly budget: shows it, or "Not set"; tapping sets, changes or removes it.
class _BudgetRow extends ConsumerWidget {
  const _BudgetRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final arabic = ref.watch(localeProvider).languageCode == 'ar';
    final budget = ref.watch(monthlyBudgetProvider).value;
    return SettingsRow(
      icon: LucideIcons.wallet,
      color: const Color(0xFFFFB340),
      title: t.insMonthlyBudget,
      value: budget == null
          ? t.insMonthlyBudgetNotSet
          : ltrIsolate(formatSar(budget, arabic: arabic)),
      onTap: () => showMonthlyBudgetFlow(context, ref, current: budget),
    );
  }
}

class _CaptureStatusRow extends ConsumerWidget {
  const _CaptureStatusRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final status = ref.watch(captureStatusProvider).value;
    final waiting = status == null
        ? ''
        : (status.pending == 0
              ? t.captureNone
              : t.captureWaiting(status.pending));
    final last = captureLastLabel(t, status?.last ?? '');
    return SettingsRow(
      icon: LucideIcons.messageSquare,
      color: const Color(0xFF3CC4A8),
      title: t.captureStatus,
      subtitle: last.isEmpty ? waiting : '$waiting · $last',
      onTap: () => context.push(capturePath),
    );
  }
}
