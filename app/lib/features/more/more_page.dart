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
import '../account/account_providers.dart';
import '../ai/providers.dart';
import '../insights/budget_flow.dart';
import '../insights/providers.dart' show monthlyBudgetProvider;
import '../../ui/app_card.dart';
import '../../ui/app_form.dart';
import '../../ui/chevron.dart';
import '../../ui/icon_tile.dart';
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
    final accounts = ref.watch(ownAccountsProvider).value;
    // The mockup's order: the account on top; money and capture; the app's own switches; sign out.
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
                _AccountCard(
                  title: t.moreYourAccount,
                  subtitle: auth.email ?? auth.displayName ?? '',
                  onTap: () => context.push(accountPath),
                ),
                const SizedBox(height: 16),
                SettingsGroup(
                  children: [
                    const _BudgetRow(),
                    SettingsRow(
                      key: const ValueKey('more-rules'),
                      icon: LucideIcons.list,
                      color: const Color(0xFFCDB4FF),
                      title: t.moreCategoriesRules,
                      onTap: () => context.push(rulesPath),
                    ),
                    SettingsRow(
                      key: const ValueKey('more-banks'),
                      icon: LucideIcons.landmark,
                      color: const Color(0xFF9CC4FF),
                      title: t.accountBanks,
                      value: accounts == null || accounts.isEmpty
                          ? null
                          : '${accounts.length}',
                      onTap: () => context.push(banksPath),
                    ),
                    const _CaptureStatusRow(),
                  ],
                ),
                const SizedBox(height: 16),
                SettingsGroup(
                  children: [
                    const _AiRow(),
                    // Only paying accounts: AI reading of unknown banks needs the paid plan.
                    if (ref.watch(aiAllowedProvider).value == true)
                      const _AiParseRow(),
                    SettingsRow(
                      icon: LucideIcons.globe,
                      color: const Color(0xFF9BE7E0),
                      title: t.language,
                      value: locale.languageCode == 'ar'
                          ? t.languageArabic
                          : t.languageEnglish,
                      onTap: () => _pickLanguage(context, ref),
                    ),
                    SettingsRow(
                      key: const ValueKey('more-reminders'),
                      icon: LucideIcons.bell,
                      color: const Color(0xFFFFA574),
                      title: t.remindersTitle,
                      control: appSwitch(
                        context,
                        value: ref.watch(remindersEnabledProvider),
                        onChanged: (on) => _toggleReminders(context, ref, on),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SecondaryButton(
                  label: t.signOut,
                  onPressed: () async {
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
          ),
          const BottomInset(),
        ],
      ),
    );
  }
}

/// The account card on top of More: a big mint tile, "Your account" and the email.
class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final muted = AppTokens.muted.resolveFrom(context);
    return Semantics(
      button: true,
      label: '$title, $subtitle',
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        key: const ValueKey('more-account'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AppCard(
          pressable: true,
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              IconTile(
                color: AppTokens.okBg.resolveFrom(context),
                icon: LucideIcons.user,
                size: 56,
                radius: 16,
                iconSize: 26,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppTokens.text.resolveFrom(context),
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: muted,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ForwardChevron(size: 14, color: muted),
            ],
          ),
        ),
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
    final t = AppLocalizations.of(context);
    // Turning it on says first what is sent and to whom (the row has no subtitle in the redesign).
    if (on) {
      final ok = await showConfirmSheet(
        context,
        title: t.aiAskTitle,
        message: t.aiAskBody,
        confirmLabel: t.aiAskConfirm,
        icon: LucideIcons.sparkles,
        iconColor: AppTokens.gold.resolveFrom(context),
      );
      if (ok != true || !mounted) return;
    }
    setState(() => _pending = on);
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
        key: const ValueKey('more-ai'),
        icon: LucideIcons.sparkles,
        color: const Color(0xFFFFC93C),
        title: t.aiTitle,
        subtitle: t.aiPaidOnly,
      );
    }
    return SettingsRow(
      key: const ValueKey('more-ai'),
      icon: LucideIcons.sparkles,
      color: const Color(0xFFFFC93C),
      title: t.aiTitle,
      control: appSwitch(context, value: _pending ?? stored, onChanged: _set),
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
      key: const ValueKey('more-ai-parse'),
      icon: LucideIcons.scanText,
      color: const Color(0xFF9CC4FF),
      title: t.aiParseTitle,
      subtitle: t.aiParseSubtitle,
      control: appSwitch(context, value: _pending ?? stored, onChanged: _set),
    );
  }
}

/// The monthly budget: shows it, or "Not set"; tapping sets, changes or removes it.
class _BudgetRow extends ConsumerWidget {
  const _BudgetRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final arabic = ref.watch(localeProvider).languageCode == 'ar';
    final budget = ref.watch(monthlyBudgetProvider).value;
    return SettingsRow(
      icon: LucideIcons.target,
      color: const Color(0xFFFFC93C),
      title: t.insMonthlyBudget,
      value: budget == null
          ? t.insMonthlyBudgetNotSet
          : ltrIsolate(formatSar(budget, arabic: arabic)),
      onTap: () => showMonthlyBudgetFlow(context, ref, current: budget),
    );
  }
}

/// Shows how the last send of the "Add bank message" Shortcuts action went, or how many messages wait.
class _CaptureStatusRow extends ConsumerWidget {
  const _CaptureStatusRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final status = ref.watch(captureStatusProvider).value;
    // Messages waiting say more than the last send; otherwise "Last sent 11:20" (or that it failed).
    final value = status == null
        ? null
        : (status.pending > 0
              ? t.captureWaiting(status.pending)
              : captureLastLabel(t, status.last));
    return SettingsRow(
      key: const ValueKey('more-capture'),
      icon: LucideIcons.messageSquare,
      color: const Color(0xFF3FD79B),
      title: t.captureStatus,
      value: value == null || value.isEmpty ? null : value,
      onTap: () => context.push(capturePath),
    );
  }
}
