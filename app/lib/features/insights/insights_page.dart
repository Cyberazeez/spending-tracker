import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/lock.dart';
import '../../core/models.dart';
import '../../core/money.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/category_sheet.dart';
import '../../core/format.dart';
import '../../ui/app_card.dart';
import '../../ui/bottom_inset.dart';
import '../../ui/empty_state.dart';
import '../../ui/skeleton.dart';
import '../../ui/tokens.dart';
import '../ai/widgets/ai_tips_card.dart';
import '../home/category_groups.dart';
import '../obligations/logic.dart' show riyadhToday;
import '../transactions/providers.dart';
import 'metrics.dart';
import 'providers.dart';
import 'widgets/donut_share.dart';
import '../../ui/choice_sheet.dart';
import 'budget_flow.dart';
import 'widgets/insight_cards.dart';
import 'widgets/month_bars.dart';
import 'widgets/trend_chart.dart';

class InsightsPage extends ConsumerStatefulWidget {
  const InsightsPage({super.key});

  @override
  ConsumerState<InsightsPage> createState() => _InsightsPageState();
}

class _InsightsPageState extends ConsumerState<InsightsPage> {
  Future<void> _budgetActions(
    String categoryId,
    String name,
    Budget? existing,
  ) async {
    final t = AppLocalizations.of(context);
    final choice = await showChoiceSheet<String>(
      context,
      title: name,
      options: [
        ChoiceOption(
          value: 'set',
          label: t.insBudgetSet,
          icon: LucideIcons.pencil,
        ),
        if (existing != null)
          ChoiceOption(
            value: 'remove',
            label: t.insBudgetRemove,
            icon: LucideIcons.trash2,
            destructive: true,
          ),
      ],
    );
    if (choice == null || !mounted) return;
    final repo = ref.read(dataRepositoryProvider);
    if (choice == 'remove') {
      await _save(() => repo.removeBudget(categoryId));
      return;
    }
    final halalas = await _askLimit(existing?.limitHalalas, subtitle: name);
    if (halalas == null || !mounted) return;
    await _save(() => repo.setBudget(categoryId, halalas));
  }

  Future<void> _monthlyBudgetActions(int? current) =>
      showMonthlyBudgetFlow(context, ref, current: current);

  Future<void> _pickCategoryForBudget(
    List<Category> cats,
    Map<String, Budget> budgetOf,
    bool arabic,
  ) async {
    final t = AppLocalizations.of(context);
    final pickedId = await showCategorySheet(
      context,
      cats: cats,
      arabic: arabic,
      title: t.insBudgetSet,
    );
    final picked = cats.where((c) => c.id == pickedId).firstOrNull;
    if (picked == null || !mounted) return;
    await _budgetActions(
      picked.id,
      picked.label(arabic: arabic),
      budgetOf[picked.id],
    );
  }

  Future<int?> _askLimit(int? current, {String? subtitle}) =>
      askBudgetLimit(context, current, subtitle: subtitle, monthly: false);

  Future<void> _save(Future<void> Function() action) =>
      saveBudgetChange(context, ref, action);

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final arabic = ref.watch(localeProvider).languageCode == 'ar';
    final data = ref.watch(insightsProvider);
    final cats = ref.watch(categoriesProvider).value ?? const <Category>[];
    final budgets = ref.watch(budgetsProvider).value ?? const <Budget>[];
    final monthlyBudget = ref.watch(monthlyBudgetProvider).value;
    final byId = {for (final c in cats) c.id: c};
    final budgetOf = {for (final b in budgets) b.categoryId: b};
    String name(String? id) => id == null
        ? t.categoryNone
        : (byId[id]?.label(arabic: arabic) ?? t.categoryNone);
    String sar(int h) => formatSar(h, arabic: arabic);

    return CupertinoPageScaffold(
      backgroundColor: AppTokens.bg.resolveFrom(context),
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: Text(t.tabInsights),
            backgroundColor: AppTokens.bg.resolveFrom(context),
            border: null,
          ),
          CupertinoSliverRefreshControl(
            onRefresh: () async {
              ref.invalidate(insightsProvider);
              ref.invalidate(budgetsProvider);
              ref.invalidate(monthlyBudgetProvider);
              ref.invalidate(categoriesProvider);
              await ref
                  .read(insightsProvider.future)
                  .catchError((_) => computeInsights(const [], DateTime.now()));
            },
          ),
          ...data.when(
            loading: () => [
              const SkeletonSliver(heights: [170, 210, 200]),
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
              if (!ins.hasData) {
                return [
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      icon: CupertinoIcons.chart_pie,
                      title: t.insEmpty,
                      body: t.insEmptyBody,
                    ),
                  ),
                ];
              }
              final alerts = <(String, BudgetLevel)>[];
              for (final c in ins.byCategory) {
                final b = c.categoryId == null ? null : budgetOf[c.categoryId];
                if (b == null) continue;
                final level = budgetLevel(c.halalas, b.limitHalalas);
                if (level == BudgetLevel.warn) {
                  alerts.add((
                    t.insBudgetWarn(
                      name(c.categoryId),
                      ((c.halalas * 100) ~/ b.limitHalalas).toString(),
                    ),
                    level,
                  ));
                } else if (level == BudgetLevel.over) {
                  alerts.add((t.insBudgetOver(name(c.categoryId)), level));
                }
              }
              final groups = groupSpend(ins.byCategory, cats);
              final categoryRows = [
                ...ins.byCategory,
                // a budget on a category with no spend yet still shows (and can be changed or removed)
                for (final b in budgets)
                  if (!ins.byCategory.any((c) => c.categoryId == b.categoryId))
                    CategorySpend(b.categoryId, 0),
              ];
              const gap = SizedBox(height: 16);
              return [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  sliver: SliverList.list(
                    children: [
                      if (alerts.isNotEmpty) ...[
                        AppCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (final a in alerts)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        LucideIcons.circleAlert,
                                        size: 20,
                                        color: a.$2 == BudgetLevel.over
                                            ? AppTokens.danger.resolveFrom(
                                                context,
                                              )
                                            : AppTokens.warnText.resolveFrom(
                                                context,
                                              ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          a.$1,
                                          style: TextStyle(
                                            color: AppTokens.text.resolveFrom(
                                              context,
                                            ),
                                            fontSize: 15,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                        gap,
                      ],
                      SummaryCard(
                        insights: ins,
                        monthlyBudget: monthlyBudget,
                        arabic: arabic,
                        onBudgetTap: () => _monthlyBudgetActions(monthlyBudget),
                      ),
                      gap,
                      AiTipsCard(
                        insights: ins,
                        categories: cats,
                        budgets: budgets,
                        today: riyadhToday(ref.watch(clockProvider)()),
                      ),
                      TrendChart(
                        thisMonth: ins.cumulativeThisMonth,
                        lastMonth: ins.cumulativeLastMonth,
                        arabic: arabic,
                      ),
                      gap,
                      MonthBars(
                        totals: ins.monthTotals,
                        budgetHalalas: monthlyBudget,
                        arabic: arabic,
                      ),
                      if (groups.isNotEmpty) ...[
                        gap,
                        DonutShare(
                          groups: groups,
                          totalHalalas: ins.monthSpend,
                          arabic: arabic,
                        ),
                      ],
                      gap,
                      ListCard(
                        title: t.insByCategory,
                        children: [
                          for (final c in categoryRows)
                            CategoryBudgetRow(
                              name: name(c.categoryId),
                              categoryName: byId[c.categoryId]?.name,
                              spent: c.halalas,
                              budget: budgetOf[c.categoryId]?.limitHalalas,
                              arabic: arabic,
                              onTap: c.categoryId == null
                                  ? null
                                  : () => _budgetActions(
                                      c.categoryId!,
                                      name(c.categoryId),
                                      budgetOf[c.categoryId],
                                    ),
                            ),
                          Semantics(
                            button: true,
                            label: t.insBudgetSet,
                            excludeSemantics: true,
                            onTap: () => _pickCategoryForBudget(
                              cats.where((c) => !c.excludedFromSpend).toList(),
                              budgetOf,
                              arabic,
                            ),
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => _pickCategoryForBudget(
                                cats
                                    .where((c) => !c.excludedFromSpend)
                                    .toList(),
                                budgetOf,
                                arabic,
                              ),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  minHeight: 44,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      LucideIcons.plus,
                                      size: 20,
                                      color: AppTokens.accentText.resolveFrom(
                                        context,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        t.insBudgetSet,
                                        style: TextStyle(
                                          color: AppTokens.accentText
                                              .resolveFrom(context),
                                          fontSize: 15,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (ins.topMerchants.isNotEmpty) ...[
                        gap,
                        ListCard(
                          title: t.insTopMerchants,
                          children: [
                            for (var i = 0; i < ins.topMerchants.length; i++)
                              InsightLine(
                                leading: _Rank(i + 1),
                                title: ins.topMerchants[i].label,
                                subtitle: ins.topMerchants[i].count == 1
                                    ? t.insVisit
                                    : t.insVisits(ins.topMerchants[i].count),
                                amount: sar(ins.topMerchants[i].halalas),
                              ),
                          ],
                        ),
                      ],
                      if (ins.spikes.isNotEmpty) ...[
                        gap,
                        ListCard(
                          title: t.insSpikes,
                          children: [
                            for (final s in ins.spikes)
                              InsightLine(
                                title: name(s.categoryId),
                                subtitle: t.insSpikeLine(
                                  ltrIsolate(sar(s.thisMonth)),
                                  ltrIsolate(sar(s.average)),
                                ),
                              ),
                          ],
                        ),
                      ],
                      if (ins.subscriptions.isNotEmpty) ...[
                        gap,
                        ListCard(
                          title: t.insSubs,
                          footer: Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              t.insSubsTotal(
                                ltrIsolate(sar(ins.subscriptionsMonthly)),
                              ),
                              style: TextStyle(
                                color: AppTokens.muted.resolveFrom(context),
                                fontSize: 13,
                              ),
                            ),
                          ),
                          children: [
                            for (final s in ins.subscriptions)
                              InsightLine(
                                title: s.label,
                                amount: sar(s.monthlyHalalas),
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

class _Rank extends StatelessWidget {
  const _Rank(this.n);
  final int n;

  @override
  Widget build(BuildContext context) => Container(
    width: 32,
    height: 32,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: AppTokens.bar.resolveFrom(context),
      shape: BoxShape.circle,
    ),
    child: Text(
      '$n',
      style: TextStyle(
        color: AppTokens.text.resolveFrom(context),
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}
