import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/lock.dart';
import '../../core/models.dart';
import '../../core/money.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/info_tile.dart';
import '../../ui/bottom_inset.dart';
import '../../ui/empty_state.dart';
import '../insights/metrics.dart';
import 'logic.dart';
import 'providers.dart';

class ObligationsPage extends ConsumerStatefulWidget {
  const ObligationsPage({super.key});

  @override
  ConsumerState<ObligationsPage> createState() => _ObligationsPageState();
}

class _ObligationsPageState extends ConsumerState<ObligationsPage> {
  ObSection _section = ObSection.upcoming;

  Future<void> _run(Future<void> Function() action) async {
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
      if (mounted) {
        ref.invalidate(obligationsProvider);
        ref.invalidate(monthSpendProvider);
      }
    }
  }

  Future<void> _rowActions(ObligationInstance i, String status) async {
    final t = AppLocalizations.of(context);
    final repo = ref.read(dataRepositoryProvider);
    final choice = await showCupertinoModalPopup<String>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(i.name),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(ctx, 'amount'),
            child: Text(t.obEditAmount),
          ),
          if (status == 'pending' || status == 'overdue') ...[
            CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(ctx, 'paid'),
              child: Text(t.obMarkPaid),
            ),
            CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(ctx, 'skipped'),
              child: Text(t.obSkip),
            ),
          ] else
            CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(ctx, 'pending'),
              child: Text(t.obReopen),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: Text(t.cancel),
        ),
      ),
    );
    if (choice == null) return;
    if (choice == 'amount') {
      final paid = status == 'paid';
      final current = paid
          ? (i.actualHalalas ?? i.expectedHalalas)
          : i.expectedHalalas;
      final v = await _askAmount(current);
      if (v == null) return;
      await _run(() => repo.setInstanceAmount(i.id, v, paid: paid));
      return;
    }
    await _run(() => repo.setInstanceStatus(i.id, choice));
  }

  Future<int?> _askAmount(int? current) async {
    final t = AppLocalizations.of(context);
    final controller = TextEditingController(
      text: current == null ? '' : (current / 100).toStringAsFixed(2),
    );
    String? error;
    final result = await showCupertinoDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => CupertinoAlertDialog(
          title: Text(t.obEditAmountPrompt),
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
                  setLocal(() => error = t.obAmountInvalid);
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
    controller.dispose();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final arabic = ref.watch(localeProvider).languageCode == 'ar';
    final today = riyadhToday(ref.watch(clockProvider)());
    final data = ref.watch(obligationsProvider);
    final spend = ref.watch(monthSpendProvider).value;
    final repo = ref.read(dataRepositoryProvider);
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);

    return CupertinoPageScaffold(
      child: CustomScrollView(
        slivers: [
          CupertinoSliverNavigationBar(largeTitle: Text(t.tabObligations)),
          CupertinoSliverRefreshControl(
            onRefresh: () async {
              ref.invalidate(obligationsProvider);
              ref.invalidate(monthSpendProvider);
              await ref
                  .read(obligationsProvider.future)
                  .catchError((_) => <ObligationInstance>[]);
            },
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: CupertinoSlidingSegmentedControl<ObSection>(
                groupValue: _section,
                onValueChanged: (v) => setState(() => _section = v ?? _section),
                children: {
                  ObSection.upcoming: Text(t.obSegUpcoming),
                  ObSection.overdue: Text(t.obSegOverdue),
                  ObSection.history: Text(t.obSegHistory),
                },
              ),
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
                    onPressed: () => ref.invalidate(obligationsProvider),
                    child: Text(t.tryAgain),
                  ),
                ),
              ),
            ],
            data: (all) {
              final suggestions = all.where((i) => i.isSuggestion).toList();
              final rows = inSection(all, _section, today);
              final month = thisMonth(all, today);
              final committedMonth = month.fold<int>(
                0,
                (s, i) => s + (i.expectedHalalas ?? 0),
              );
              final paidMonth = month
                  .where((i) => i.status == 'paid')
                  .fold<int>(0, (s, i) => s + (i.actualHalalas ?? 0));
              return [
                if (suggestions.isNotEmpty)
                  SliverToBoxAdapter(
                    child: CupertinoListSection.insetGrouped(
                      children: [
                        for (final s in suggestions)
                          InfoTile(
                            title: Text(t.obSuggestTitle(s.name)),
                            subtitle: Row(
                              children: [
                                CupertinoButton(
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(0, 32),
                                  onPressed: () =>
                                      _run(() => repo.confirmMatch(s.id)),
                                  child: Text(t.obConfirm),
                                ),
                                const SizedBox(width: 16),
                                CupertinoButton(
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(0, 32),
                                  onPressed: () =>
                                      _run(() => repo.rejectMatch(s.id)),
                                  child: Text(t.obNotThis),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                if (_section == ObSection.upcoming)
                  SliverToBoxAdapter(
                    child: CupertinoListSection.insetGrouped(
                      children: [
                        InfoTile(
                          title: Text(t.obCommitted),
                          additionalInfo: _amount(
                            committedHalalas(rows),
                            arabic,
                          ),
                        ),
                        InfoTile(
                          title: Text(t.obMonthCommitted),
                          subtitle: Text(t.obMonthCommittedNote),
                          additionalInfo: _amount(committedMonth, arabic),
                        ),
                        if (spend != null)
                          InfoTile(
                            title: Text(t.obMonthOther),
                            subtitle: Text(t.obMonthTitle),
                            additionalInfo: _amount(
                              (spend - paidMonth).clamp(0, 1 << 40),
                              arabic,
                            ),
                          ),
                      ],
                    ),
                  ),
                if (rows.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      icon: CupertinoIcons.calendar,
                      title: switch (_section) {
                        ObSection.upcoming => t.obEmptyUpcoming,
                        ObSection.overdue => t.obEmptyOverdue,
                        ObSection.history => t.obEmptyHistory,
                      },
                    ),
                  )
                else if (_section == ObSection.upcoming)
                  // One box per month so "this month" and "next month" never blur together.
                  for (final g in groupByMonth(rows, today))
                    SliverToBoxAdapter(
                      child: CupertinoListSection.insetGrouped(
                        header: Text(
                          _groupTitle(g.monthStart, today, arabic, t),
                        ),
                        children: [
                          for (final i in g.items)
                            _row(i, today, arabic, secondary, t),
                        ],
                      ),
                    )
                else
                  SliverToBoxAdapter(
                    child: CupertinoListSection.insetGrouped(
                      children: [
                        for (final i in rows)
                          _row(i, today, arabic, secondary, t),
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

  String _groupTitle(
    DateTime monthStart,
    DateTime today,
    bool arabic,
    AppLocalizations t,
  ) {
    final name = monthName(monthStart, arabic: arabic);
    final diff =
        (monthStart.year - today.year) * 12 + monthStart.month - today.month;
    if (diff == 0) return t.obGroupThis(name);
    if (diff == 1) return t.obGroupNext(name);
    return t.obGroupLater(name, monthStart.year.toString());
  }

  Widget _amount(int halalas, bool arabic) => Directionality(
    textDirection: TextDirection.ltr,
    child: Text(formatSar(halalas, arabic: arabic)),
  );

  Widget _row(
    ObligationInstance i,
    DateTime today,
    bool arabic,
    Color secondary,
    AppLocalizations t,
  ) {
    final status = effectiveStatus(i, today);
    final label = switch (status) {
      'paid' => t.obStatusPaid,
      'overdue' => t.obStatusOverdue,
      'skipped' => t.obStatusSkipped,
      _ => t.obStatusPending,
    };
    final color = switch (status) {
      'paid' => CupertinoColors.systemGreen.resolveFrom(context),
      'overdue' => CupertinoColors.systemRed.resolveFrom(context),
      _ => secondary,
    };
    final planNo = i.kind == 'card_statement' && i.plan != null
        ? i.plan!.numberFor(i.periodStart ?? i.dueDate)
        : null;
    final amounts = [
      if (i.expectedHalalas != null)
        t.obExpected(formatSar(i.expectedHalalas!, arabic: arabic)),
      if (i.usualMinHalalas != null &&
          i.usualMaxHalalas != null &&
          i.status != 'paid')
        t.obUsually(
          formatSar(i.usualMinHalalas!, arabic: arabic),
          formatSar(i.usualMaxHalalas!, arabic: arabic),
        ),
      if (status == 'paid' && i.actualHalalas != null)
        t.obPaidAmount(formatSar(i.actualHalalas!, arabic: arabic)),
    ].join(' · ');
    return InfoTile(
      onTap: () => _rowActions(i, status),
      title: Text(i.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        [
          t.obDue(formatDay(i.dueDate)),
          if (amounts.isNotEmpty) amounts,
          if (planNo != null)
            t.obPlanNote(
              i.plan!.name,
              planNo.toString(),
              i.plan!.months.toString(),
              formatSar(i.plan!.instalmentHalalas, arabic: arabic),
            ),
        ].join(' · '),
      ),
      additionalInfo: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
