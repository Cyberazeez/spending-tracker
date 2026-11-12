import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/lock.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../router.dart';
import '../../ui/bottom_inset.dart';
import '../../ui/app_card.dart';
import '../../ui/empty_state.dart';
import '../../ui/skeleton.dart';
import '../../ui/tokens.dart';
import '../insights/metrics.dart';
import '../insights/providers.dart';
import '../obligations/logic.dart';
import '../obligations/providers.dart';
import '../shell/tabs.dart';
import '../transactions/providers.dart';
import 'category_groups.dart';
import 'logic.dart';
import 'widgets/welcome_card.dart';
import 'widgets/attention_chip.dart';
import 'widgets/bill_card.dart';
import 'widgets/hero_card.dart';
import 'widgets/share_bar.dart';
import 'widgets/week_bars.dart';
import '../../ui/app_form.dart';
import '../../ui/halala_logo.dart';
import '../../ui/press.dart';
import '../../ui/swipe_action.dart' show swipeLabelColor;

/// The first tab: this month at a glance, what is due next, and anything that needs the owner's attention.
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final arabic = ref.watch(localeProvider).languageCode == 'ar';
    final now = ref.watch(clockProvider)();
    final today = riyadhToday(now);
    final data = ref.watch(insightsProvider);
    final cats = ref.watch(categoriesProvider).value ?? const <Category>[];
    final budgets = ref.watch(budgetsProvider).value ?? const <Budget>[];
    final today0 = ref.watch(todaySpendProvider).value;
    final monthlyBudget = ref.watch(monthlyBudgetProvider).value;
    final reviewCount = ref.watch(reviewCountProvider);
    final gaps = ref.watch(senderGapsProvider).value ?? const <SenderGap>[];
    final obligations =
        ref.watch(obligationsProvider).value ?? const <ObligationInstance>[];
    String name(String? id) => id == null
        ? t.categoryNone
        : (cats.where((c) => c.id == id).firstOrNull?.label(arabic: arabic) ??
              t.categoryNone);
    final ins0 = data.value;
    final silent = silentDays(gaps, now);
    final next = [
      ...inSection(obligations, ObSection.overdue, today),
      ...inSection(obligations, ObSection.upcoming, today),
    ].take(3).toList();

    final groups = groupSpend(ins0?.byCategory ?? const [], cats);

    return CupertinoPageScaffold(
      backgroundColor: AppTokens.bg.resolveFrom(context),
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: Text(t.tabHome),
            backgroundColor: AppTokens.bg.resolveFrom(context),
            border: null,
          ),
          CupertinoSliverRefreshControl(
            onRefresh: () async {
              ref.invalidate(insightsProvider);
              ref.invalidate(budgetsProvider);
              ref.invalidate(todaySpendProvider);
              ref.invalidate(monthlyBudgetProvider);
              ref.invalidate(categoriesProvider);
              ref.invalidate(obligationsProvider);
              ref.invalidate(needsReviewProvider);
              ref.invalidate(aiReadProvider);
              ref.invalidate(senderGapsProvider);
              await ref
                  .read(insightsProvider.future)
                  .catchError((_) => computeInsights(const [], now));
            },
          ),
          ...data.when(
            loading: () => [
              const SkeletonSliver(heights: [200, 170, 220]),
            ],
            error: (_, _) => [
              SliverFillRemaining(
                hasScrollBody: false,
                child: LoadFailedCard(
                  onRetry: () => ref.invalidate(insightsProvider),
                ),
              ),
            ],
            data: (ins) {
              final settling =
                  ref.watch(senderGapsProvider).isLoading ||
                  ref.watch(obligationsProvider).isLoading;
              if (settling && !ins.hasData) {
                return [
                  const SkeletonSliver(heights: [200, 170, 220]),
                ];
              }
              if (!ins.hasData && gaps.isEmpty && obligations.isEmpty) {
                // New account, nothing yet: the logo, what to do first, then the getting-started steps.
                return [
                  const SliverPadding(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate.fixed([
                        _FirstSmsCard(),
                        SizedBox(height: 16),
                        WelcomeCard(showSteps: false),
                      ]),
                    ),
                  ),
                ];
              }
              final diff = ins.monthSpend - ins.lastMonthToDate;
              final alerts = budgetAlerts(ins, budgets);
              final monthlyLevel = monthlyBudget == null
                  ? BudgetLevel.ok
                  : budgetLevel(ins.monthSpend, monthlyBudget);
              return [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  sliver: SliverList.list(
                    children: [
                      const WelcomeCard(),
                      if (silent != null) ...[
                        _NoticeCard(
                          icon: LucideIcons.triangleAlert,
                          color: AppTokens.warnText.resolveFrom(context),
                          text: t.homeStale(silent.toString()),
                          onTap: () => context.push(capturePath),
                        ),
                        const SizedBox(height: 16),
                      ],
                      HeroCard(
                        monthHalalas: ins.monthSpend,
                        todayHalalas: today0,
                        budgetHalalas: monthlyBudget,
                        lastMonthDiffHalalas: ins.lastMonthHasData
                            ? diff
                            : null,
                        lastMonthPercent:
                            ins.lastMonthHasData && ins.lastMonthToDate > 0
                            ? (diff * 100 / ins.lastMonthToDate).round()
                            : null,
                        arabic: arabic,
                      ),
                      // Things that want a look, as chips under the hero: messages to review, budgets near or
                      // over their limit.
                      if (reviewCount > 0 ||
                          alerts.isNotEmpty ||
                          monthlyLevel != BudgetLevel.ok) ...[
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (reviewCount > 0)
                              _HomeChip(
                                label: t.homeToReview(reviewCount),
                                fill: AppTokens.gold.resolveFrom(context),
                                onTap: () => context.push(reviewPath),
                              ),
                            if (monthlyLevel != BudgetLevel.ok)
                              _HomeChip(
                                label: monthlyLevel == BudgetLevel.over
                                    ? t.homeChipMonthlyOver
                                    : t.homeChipMonthly(
                                        budgetPercent(
                                          ins.monthSpend,
                                          monthlyBudget,
                                        ).toString(),
                                      ),
                                fill: monthlyLevel == BudgetLevel.over
                                    ? AppTokens.danger.resolveFrom(context)
                                    : const Color(0xFFFFA574),
                                onTap: () =>
                                    ref.read(tabControllerProvider).index =
                                        tabInsights,
                              ),
                            for (final a in alerts)
                              _HomeChip(
                                label: a.level == BudgetLevel.over
                                    ? t.homeChipOver(name(a.categoryId))
                                    : t.homeChipBudget(
                                        name(a.categoryId),
                                        a.percent.toString(),
                                      ),
                                fill: a.level == BudgetLevel.over
                                    ? AppTokens.danger.resolveFrom(context)
                                    : const Color(0xFFFFA574),
                                onTap: () =>
                                    ref.read(tabControllerProvider).index =
                                        tabInsights,
                              ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 16),
                      WeekBars(days: ins.last7Days, arabic: arabic),
                      if (groups.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        ShareBar(
                          top: groups.take(4).toList(),
                          totalHalalas: ins.monthSpend,
                          arabic: arabic,
                          onSeeAll: () =>
                              ref.read(tabControllerProvider).index =
                                  tabInsights,
                        ),
                      ],
                      const SizedBox(height: 20),
                      _SectionHeader(
                        title: t.homeNextBills,
                        action: t.homeAllBills,
                        onAction: () => ref.read(tabControllerProvider).index =
                            tabObligations,
                      ),
                      const SizedBox(height: 12),
                      if (next.isEmpty)
                        AppCard(child: Text(t.homeNothingDue))
                      else
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                for (final i in next) ...[
                                  SizedBox(
                                    width: 176,
                                    child: BillCard(
                                      bill: i,
                                      today: today,
                                      arabic: arabic,
                                      onTap: () =>
                                          ref
                                                  .read(tabControllerProvider)
                                                  .index =
                                              tabObligations,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                ],
                              ],
                            ),
                          ),
                        ),
                      if (silent != null) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10,
                          children: [
                            AttentionChip(
                              label: t.captureStatus,
                              dot: const Color(0xFFFF6B66),
                              onTap: () => context.push(capturePath),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ];
            },
          ),
          const BottomInset(),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.action,
    required this.onAction,
  });
  final String title;
  final String action;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Padding(
          padding: const EdgeInsetsDirectional.only(start: 4),
          child: Text(
            title,
            style: TextStyle(
              color: AppTokens.text.resolveFrom(context),
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
      CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: const Size(44, 44),
        onPressed: onAction,
        child: Text(
          action,
          style: TextStyle(
            color: AppTokens.accentText.resolveFrom(context),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    ],
  );
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({
    required this.icon,
    required this.color,
    required this.text,
    required this.onTap,
  });
  final IconData icon;
  final Color color;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: AppCard(
      pressable: true,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: AppTokens.text.resolveFrom(context),
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// A chip under the hero for something that wants a look; filled, with ink text (white on the red of "over").
class _HomeChip extends StatelessWidget {
  const _HomeChip({
    required this.label,
    required this.fill,
    required this.onTap,
  });
  final String label;
  final Color fill;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    excludeSemantics: true,
    child: CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: const Size(44, 44),
      pressedOpacity: 1,
      onPressed: onTap,
      child: PressShadow(
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(20),
          border: outlineOf(context, width: AppTokens.outlineThin),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          child: Text(
            label,
            style: TextStyle(
              color: swipeLabelColor(fill),
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    ),
  );
}

/// Home for a new account with nothing yet: the logo, what happens next, and the two ways to start.
class _FirstSmsCard extends StatelessWidget {
  const _FirstSmsCard();

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return AppCard(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      child: Column(
        children: [
          const HalalaLogo(width: 170),
          const SizedBox(height: 20),
          Text(
            t.emptyHomeTitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTokens.text.resolveFrom(context),
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            t.emptyHomeBody,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTokens.muted.resolveFrom(context),
              fontSize: 15,
              fontWeight: FontWeight.w500,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          PrimaryButton(
            label: t.captureSetupTitle,
            icon: LucideIcons.messageSquare,
            onPressed: () => context.push(capturePath),
          ),
          const SizedBox(height: 10),
          SecondaryButton(
            label: t.homeAddByHand,
            icon: LucideIcons.plus,
            onPressed: () => context.push(quickAddPath),
          ),
        ],
      ),
    );
  }
}
