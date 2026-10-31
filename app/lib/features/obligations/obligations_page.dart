import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/lock.dart';
import '../../core/models.dart';
import '../../core/money.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/empty_state.dart';
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
    await _run(() => repo.setInstanceStatus(i.id, choice));
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
                          CupertinoListTile(
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
                        CupertinoListTile(
                          title: Text(t.obCommitted),
                          additionalInfo: _amount(
                            committedHalalas(rows),
                            arabic,
                          ),
                        ),
                        CupertinoListTile(
                          title: Text(t.obMonthCommitted),
                          subtitle: Text(t.obMonthTitle),
                          additionalInfo: _amount(committedMonth, arabic),
                        ),
                        if (spend != null)
                          CupertinoListTile(
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
        ],
      ),
    );
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
    final amounts = [
      if (i.expectedHalalas != null)
        t.obExpected(formatSar(i.expectedHalalas!, arabic: arabic)),
      if (status == 'paid' && i.actualHalalas != null)
        t.obPaidAmount(formatSar(i.actualHalalas!, arabic: arabic)),
    ].join(' · ');
    return CupertinoListTile(
      onTap: () => _rowActions(i, status),
      title: Text(i.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        [
          t.obDue(formatDay(i.dueDate)),
          if (amounts.isNotEmpty) amounts,
        ].join(' · '),
      ),
      trailing: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
