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
import 'widgets/attention_chip.dart';
import 'widgets/bill_card.dart';
import 'widgets/hero_card.dart';
import 'widgets/share_bar.dart';
import 'widgets/week_bars.dart';

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
    final review = ref.watch(needsReviewProvider).value ?? const <RawMessage>[];
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
            largeTitle: Text(t.homeOverview),
            backgroundColor: AppTokens.bg.resolveFrom(context),
            border: null,
            trailing: CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: const Size(44, 44),
              onPressed: () => context.go(quickAddPath),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppTokens.accent.resolveFrom(context),
                  shape: BoxShape.circle,
                ),
                child: SizedBox(
                  width: 36,
                  height: 36,
                  child: Icon(
                    LucideIcons.plus,
                    size: 20,
                    color: AppTokens.onAccent.resolveFrom(context),
                    semanticLabel: t.homeAddTx,
                  ),
                ),
              ),
            ),
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
                child: EmptyState(
                  icon: CupertinoIcons.exclamationmark_triangle,
                  title: t.loadFailed,
                  action: CupertinoButton(
                    onPressed: () => ref.invalidate(insightsProvider),
                    child: Text(t.tryAgain),
                  ),
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
                return [
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      icon: CupertinoIcons.tray,
                      title: t.emptyHomeTitle,
                      body: t.emptyHomeBody,
                    ),
                  ),
                ];
              }
              final diff = ins.monthSpend - ins.lastMonthToDate;
              final alerts = budgetAlerts(ins, budgets);
              final monthlyLevel = monthlyBudget == null
                  ? BudgetLevel.ok
                  : budgetLevel(ins.monthSpend, monthlyBudget);
              Color levelColor(BudgetLevel l) => l == BudgetLevel.over
                  ? AppTokens.danger.resolveFrom(context)
                  : AppTokens.warnText.resolveFrom(context);
              return [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  sliver: SliverList.list(
                    children: [
                      if (silent != null) ...[
                        _NoticeCard(
                          icon: LucideIcons.triangleAlert,
                          color: AppTokens.warnText.resolveFrom(context),
                          text: t.homeStale(silent.toString()),
                          onTap: () => context.go(gapsPath),
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
                      if (alerts.isNotEmpty ||
                          monthlyLevel != BudgetLevel.ok) ...[
                        const SizedBox(height: 16),
                        AppCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (monthlyLevel != BudgetLevel.ok)
                                _AlertLine(
                                  color: levelColor(monthlyLevel),
                                  text: monthlyLevel == BudgetLevel.over
                                      ? t.homeMonthlyOver
                                      : t.homeMonthlyWarn(
                                          budgetPercent(
                                            ins.monthSpend,
                                            monthlyBudget,
                                          ).toString(),
                                        ),
                                ),
                              for (final a in alerts)
                                _AlertLine(
                                  color: levelColor(a.level),
                                  text: a.level == BudgetLevel.over
                                      ? t.insBudgetOver(name(a.categoryId))
                                      : t.insBudgetWarn(
                                          name(a.categoryId),
                                          a.percent.toString(),
                                        ),
                                ),
                            ],
                          ),
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
                      if (review.isNotEmpty || gaps.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10,
                          children: [
                            if (review.isNotEmpty)
                              AttentionChip(
                                label: t.homeToReview(review.length),
                                dot: const Color(0xFFFFB340),
                                onTap: () => context.go(reviewPath),
                              ),
                            if (gaps.isNotEmpty)
                              AttentionChip(
                                label: t.gapsTitle,
                                dot: const Color(0xFFFF6B66),
                                onTap: () => context.go(gapsPath),
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
            color: AppTokens.accent.resolveFrom(context),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    ],
  );
}

class _AlertLine extends StatelessWidget {
  const _AlertLine({required this.color, required this.text});
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Icon(LucideIcons.circleAlert, size: 20, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: AppTokens.text.resolveFrom(context),
              fontSize: 15,
            ),
          ),
        ),
      ],
    ),
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
