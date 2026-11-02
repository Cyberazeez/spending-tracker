import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/lock.dart';
import '../../core/models.dart';
import '../../core/money.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/info_tile.dart';
import '../../router.dart';
import '../../ui/bottom_inset.dart';
import '../../ui/empty_state.dart';
import '../insights/metrics.dart';
import '../insights/providers.dart';
import '../obligations/logic.dart';
import '../obligations/providers.dart';
import '../transactions/providers.dart';
import 'logic.dart';

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
    String sar(int h) => formatSar(h, arabic: arabic);
    Widget ltr(String s) =>
        Directionality(textDirection: TextDirection.ltr, child: Text(s));

    final silent = silentDays(gaps, now);
    final next = [
      ...inSection(obligations, ObSection.overdue, today),
      ...inSection(obligations, ObSection.upcoming, today),
    ].take(3).toList();

    return CupertinoPageScaffold(
      child: CustomScrollView(
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: Text(t.tabHome),
            trailing: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => context.go(quickAddPath),
              child: Icon(CupertinoIcons.add, semanticLabel: t.homeAddTx),
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
          if (silent != null)
            SliverToBoxAdapter(
              child: CupertinoListSection.insetGrouped(
                children: [
                  InfoTile(
                    leading: Icon(
                      CupertinoIcons.exclamationmark_triangle_fill,
                      color: CupertinoColors.systemOrange.resolveFrom(context),
                    ),
                    title: Text(t.homeStale(silent.toString())),
                    trailing: const CupertinoListTileChevron(),
                    onTap: () => context.go(gapsPath),
                  ),
                ],
              ),
            ),
          ...data.when(
            loading: () => [
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CupertinoActivityIndicator()),
              ),
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
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: CupertinoActivityIndicator()),
                  ),
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
              return [
                SliverToBoxAdapter(
                  child: CupertinoListSection.insetGrouped(
                    header: Text(t.insThisMonth),
                    children: [
                      InfoTile(
                        title: Text(t.insSpent),
                        additionalInfo: ltr(sar(ins.monthSpend)),
                        subtitle: Text(
                          !ins.lastMonthHasData
                              ? t.insNoCompare
                              : diff == 0
                              ? t.insSame
                              : diff > 0
                              ? t.insUp(sar(diff))
                              : t.insDown(sar(-diff)),
                        ),
                      ),
                      if (today0 != null)
                        InfoTile(
                          title: Text(t.homeToday),
                          additionalInfo: ltr(sar(today0)),
                        ),
                      if (monthlyBudget != null)
                        InfoTile(
                          title: Text(t.homeBudgetUsed),
                          subtitle: Text(sar(monthlyBudget)),
                          additionalInfo: ltr(
                            '${budgetPercent(ins.monthSpend, monthlyBudget)}%',
                          ),
                        ),
                      if (ins.byCategory.isNotEmpty)
                        InfoTile(
                          title: Text(
                            t.homeTop(
                              name(ins.byCategory.first.categoryId),
                              sar(ins.byCategory.first.halalas),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (alerts.isNotEmpty || monthlyLevel != BudgetLevel.ok)
                  SliverToBoxAdapter(
                    child: CupertinoListSection.insetGrouped(
                      header: Text(t.homeAlerts),
                      children: [
                        if (monthlyLevel != BudgetLevel.ok)
                          InfoTile(
                            leading: Icon(
                              CupertinoIcons.exclamationmark_circle_fill,
                              color: monthlyLevel == BudgetLevel.over
                                  ? CupertinoColors.systemRed.resolveFrom(
                                      context,
                                    )
                                  : CupertinoColors.systemOrange.resolveFrom(
                                      context,
                                    ),
                            ),
                            title: Text(
                              monthlyLevel == BudgetLevel.over
                                  ? t.homeMonthlyOver
                                  : t.homeMonthlyWarn(
                                      budgetPercent(
                                        ins.monthSpend,
                                        monthlyBudget,
                                      ).toString(),
                                    ),
                            ),
                          ),
                        for (final a in alerts)
                          InfoTile(
                            leading: Icon(
                              CupertinoIcons.exclamationmark_circle_fill,
                              color: a.level == BudgetLevel.over
                                  ? CupertinoColors.systemRed.resolveFrom(
                                      context,
                                    )
                                  : CupertinoColors.systemOrange.resolveFrom(
                                      context,
                                    ),
                            ),
                            title: Text(
                              a.level == BudgetLevel.over
                                  ? t.insBudgetOver(name(a.categoryId))
                                  : t.insBudgetWarn(
                                      name(a.categoryId),
                                      a.percent.toString(),
                                    ),
                            ),
                          ),
                      ],
                    ),
                  ),
                SliverToBoxAdapter(
                  child: CupertinoListSection.insetGrouped(
                    header: Text(t.homeNext),
                    children: next.isEmpty
                        ? [InfoTile(title: Text(t.homeNothingDue))]
                        : [
                            for (final i in next)
                              InfoTile(
                                title: Text(
                                  i.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  i.dueDate.isBefore(today)
                                      ? '${t.obStatusOverdue} · ${t.obDue(formatDay(i.dueDate))}'
                                      : t.obDue(formatDay(i.dueDate)),
                                  style: i.dueDate.isBefore(today)
                                      ? TextStyle(
                                          color: CupertinoColors.systemRed
                                              .resolveFrom(context),
                                        )
                                      : null,
                                ),
                                additionalInfo: i.expectedHalalas == null
                                    ? null
                                    : ltr(sar(i.expectedHalalas!)),
                              ),
                          ],
                  ),
                ),
                if (review.isNotEmpty || gaps.isNotEmpty)
                  SliverToBoxAdapter(
                    child: CupertinoListSection.insetGrouped(
                      children: [
                        if (review.isNotEmpty)
                          InfoTile(
                            leading: const Icon(CupertinoIcons.tray_full),
                            title: Text(t.txOpenReview(review.length)),
                            trailing: const CupertinoListTileChevron(),
                            onTap: () => context.go(reviewPath),
                          ),
                        if (gaps.isNotEmpty)
                          InfoTile(
                            leading: const Icon(
                              CupertinoIcons.antenna_radiowaves_left_right,
                            ),
                            title: Text(t.gapsTitle),
                            trailing: const CupertinoListTileChevron(),
                            onTap: () => context.go(gapsPath),
                          ),
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
