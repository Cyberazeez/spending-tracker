import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../core/money.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/info_tile.dart';
import '../../ui/bottom_inset.dart';
import '../../ui/empty_state.dart';
import '../transactions/providers.dart';
import 'metrics.dart';
import 'providers.dart';

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
    final choice = await showCupertinoModalPopup<String>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(name),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(ctx, 'set'),
            child: Text(t.insBudgetSet),
          ),
          if (existing != null)
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.pop(ctx, 'remove'),
              child: Text(t.insBudgetRemove),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: Text(t.cancel),
        ),
      ),
    );
    if (choice == null || !mounted) return;
    final repo = ref.read(dataRepositoryProvider);
    if (choice == 'remove') {
      await _save(() => repo.removeBudget(categoryId));
      return;
    }
    final halalas = await _askLimit(existing?.limitHalalas);
    if (halalas == null || !mounted) return;
    await _save(() => repo.setBudget(categoryId, halalas));
  }

  Future<void> _pickCategoryForBudget(
    List<Category> cats,
    Map<String, Budget> budgetOf,
    bool arabic,
  ) async {
    final t = AppLocalizations.of(context);
    final picked = await showCupertinoModalPopup<Category>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(t.insBudgetSet),
        actions: [
          for (final c in cats)
            CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(ctx, c),
              child: Text(c.label(arabic: arabic)),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: Text(t.cancel),
        ),
      ),
    );
    if (picked == null || !mounted) return;
    await _budgetActions(
      picked.id,
      picked.label(arabic: arabic),
      budgetOf[picked.id],
    );
  }

  Future<int?> _askLimit(int? current) async {
    final t = AppLocalizations.of(context);
    final controller = TextEditingController(
      text: current == null ? '' : (current / 100).toStringAsFixed(2),
    );
    String? error;
    final result = await showCupertinoDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => CupertinoAlertDialog(
          title: Text(t.insBudgetPrompt),
          content: Column(
            children: [
              const SizedBox(height: 8),
              CupertinoTextField(
                controller: controller,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    error!,
                    style: TextStyle(
                      color: CupertinoColors.systemRed.resolveFrom(ctx),
                      fontSize: 13,
                    ),
                  ),
                ),
            ],
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(ctx),
              child: Text(t.cancel),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () {
                final v = parseHalalas(controller.text);
                if (v == null || v > maxBudgetHalalas) {
                  setLocal(() => error = t.insBudgetInvalid);
                } else {
                  Navigator.pop(ctx, v);
                }
              },
              child: Text(t.insSave),
            ),
          ],
        ),
      ),
    );
    return result;
  }

  Future<void> _save(Future<void> Function() action) async {
    final t = AppLocalizations.of(context);
    try {
      await action();
    } catch (_) {
      if (!mounted) return;
      await showCupertinoDialog<void>(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          content: Text(t.obSaveFailed),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(ctx),
              child: Text(t.done),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) ref.invalidate(budgetsProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final arabic = ref.watch(localeProvider).languageCode == 'ar';
    final data = ref.watch(insightsProvider);
    final cats = ref.watch(categoriesProvider).value ?? const <Category>[];
    final budgets = ref.watch(budgetsProvider).value ?? const <Budget>[];
    final byId = {for (final c in cats) c.id: c};
    final budgetOf = {for (final b in budgets) b.categoryId: b};
    String name(String? id) => id == null
        ? t.categoryNone
        : (byId[id]?.label(arabic: arabic) ?? t.categoryNone);
    String sar(int h) => formatSar(h, arabic: arabic);
    Widget ltr(String s) =>
        Directionality(textDirection: TextDirection.ltr, child: Text(s));

    return CupertinoPageScaffold(
      child: CustomScrollView(
        slivers: [
          CupertinoSliverNavigationBar(largeTitle: Text(t.tabInsights)),
          CupertinoSliverRefreshControl(
            onRefresh: () async {
              ref.invalidate(insightsProvider);
              ref.invalidate(budgetsProvider);
              ref.invalidate(categoriesProvider);
              await ref
                  .read(insightsProvider.future)
                  .catchError((_) => computeInsights(const [], DateTime.now()));
            },
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
              final diff = ins.monthSpend - ins.lastMonthToDate;
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
              final secondary = CupertinoColors.secondaryLabel.resolveFrom(
                context,
              );
              return [
                if (alerts.isNotEmpty)
                  SliverToBoxAdapter(
                    child: CupertinoListSection.insetGrouped(
                      children: [
                        for (final a in alerts)
                          InfoTile(
                            leading: Icon(
                              CupertinoIcons.exclamationmark_circle_fill,
                              color: a.$2 == BudgetLevel.over
                                  ? CupertinoColors.systemRed.resolveFrom(
                                      context,
                                    )
                                  : CupertinoColors.systemOrange.resolveFrom(
                                      context,
                                    ),
                            ),
                            title: Text(a.$1),
                          ),
                      ],
                    ),
                  ),
                SliverToBoxAdapter(
                  child: CupertinoListSection.insetGrouped(
                    header: Text(t.insThisMonth),
                    children: [
                      InfoTile(
                        title: Text(t.insSpent),
                        additionalInfo: ltr(sar(ins.monthSpend)),
                      ),
                      InfoTile(
                        title: Text(t.insVsLast),
                        additionalInfo: ltr(sar(ins.lastMonthToDate)),
                        subtitle: Text(
                          diff == 0
                              ? t.insSame
                              : diff > 0
                              ? t.insUp(sar(diff))
                              : t.insDown(sar(-diff)),
                        ),
                      ),
                      if (ins.savingsRate != null)
                        InfoTile(
                          title: Text(t.insSavings),
                          additionalInfo: ltr(
                            t.insSavingsValue(
                              (ins.savingsRate! * 100).round().toString(),
                            ),
                          ),
                        ),
                      if (ins.salaryAboveBase)
                        InfoTile(
                          leading: Icon(
                            CupertinoIcons.exclamationmark_triangle,
                            color: CupertinoColors.systemOrange.resolveFrom(
                              context,
                            ),
                          ),
                          title: Text(t.insSalaryAbove(sar(baseSalaryHalalas))),
                        ),
                    ],
                  ),
                ),
                SliverToBoxAdapter(
                  child: CupertinoListSection.insetGrouped(
                    header: Text(t.insByCategory),
                    children: [
                      for (final c in [
                        ...ins.byCategory,
                        // a budget on a category with no spend yet still shows (and can be changed or removed)
                        for (final b in budgets)
                          if (!ins.byCategory.any(
                            (c) => c.categoryId == b.categoryId,
                          ))
                            CategorySpend(b.categoryId, 0),
                      ])
                        _categoryRow(
                          context,
                          c,
                          name(c.categoryId),
                          budgetOf[c.categoryId],
                          t,
                          sar,
                          ltr,
                          secondary,
                        ),
                      InfoTile(
                        leading: const Icon(CupertinoIcons.add_circled),
                        title: Text(t.insBudgetSet),
                        onTap: () => _pickCategoryForBudget(
                          cats.where((c) => !c.excludedFromSpend).toList(),
                          budgetOf,
                          arabic,
                        ),
                      ),
                    ],
                  ),
                ),
                if (ins.topMerchants.isNotEmpty)
                  SliverToBoxAdapter(
                    child: CupertinoListSection.insetGrouped(
                      header: Text(t.insTopMerchants),
                      children: [
                        for (final m in ins.topMerchants)
                          InfoTile(
                            title: Text(
                              m.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            additionalInfo: ltr(sar(m.halalas)),
                          ),
                      ],
                    ),
                  ),
                if (ins.spikes.isNotEmpty)
                  SliverToBoxAdapter(
                    child: CupertinoListSection.insetGrouped(
                      header: Text(t.insSpikes),
                      children: [
                        for (final s in ins.spikes)
                          InfoTile(
                            title: Text(name(s.categoryId)),
                            subtitle: Text(
                              t.insSpikeLine(sar(s.thisMonth), sar(s.average)),
                            ),
                          ),
                      ],
                    ),
                  ),
                if (ins.subscriptions.isNotEmpty)
                  SliverToBoxAdapter(
                    child: CupertinoListSection.insetGrouped(
                      header: Text(t.insSubs),
                      footer: Text(
                        t.insSubsTotal(sar(ins.subscriptionsMonthly)),
                      ),
                      children: [
                        for (final s in ins.subscriptions)
                          InfoTile(
                            title: Text(
                              s.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            additionalInfo: ltr(sar(s.monthlyHalalas)),
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

  Widget _categoryRow(
    BuildContext context,
    CategorySpend c,
    String label,
    Budget? budget,
    AppLocalizations t,
    String Function(int) sar,
    Widget Function(String) ltr,
    Color secondary,
  ) {
    final level = budget == null
        ? BudgetLevel.ok
        : budgetLevel(c.halalas, budget.limitHalalas);
    final color = switch (level) {
      BudgetLevel.over => CupertinoColors.systemRed.resolveFrom(context),
      BudgetLevel.warn => CupertinoColors.systemOrange.resolveFrom(context),
      BudgetLevel.ok => CupertinoColors.activeBlue.resolveFrom(context),
    };
    return InfoTile(
      onTap: c.categoryId == null
          ? null
          : () => _budgetActions(c.categoryId!, label, budget),
      title: Text(label),
      subtitle: budget == null
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: SizedBox(
                    height: 6,
                    width: double.infinity,
                    child: LinearProgressIndicatorLike(
                      value: c.halalas / budget.limitHalalas,
                      color: color,
                      background: CupertinoColors.systemFill.resolveFrom(
                        context,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                ltr(t.insOfLimit(sar(budget.limitHalalas))),
              ],
            ),
      additionalInfo: ltr(sar(c.halalas)),
    );
  }
}

/// A thin progress bar (Cupertino has none); the fill is clamped to the full width.
class LinearProgressIndicatorLike extends StatelessWidget {
  const LinearProgressIndicatorLike({
    super.key,
    required this.value,
    required this.color,
    required this.background,
  });
  final double value;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Positioned.fill(child: ColoredBox(color: background)),
      FractionallySizedBox(
        alignment: AlignmentDirectional.centerStart,
        widthFactor: value.clamp(0.0, 1.0),
        child: ColoredBox(color: color),
      ),
    ],
  );
}
