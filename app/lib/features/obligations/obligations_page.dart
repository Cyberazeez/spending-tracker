import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/format.dart';
import '../../core/lock.dart';
import '../../core/models.dart';
import '../../core/money.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../router.dart';
import '../../ui/app_card.dart';
import '../../ui/bottom_inset.dart';
import '../../ui/empty_state.dart';
import '../../ui/skeleton.dart';
import '../../ui/choice_sheet.dart';
import '../../ui/tokens.dart';
import '../insights/metrics.dart';
import 'logic.dart';
import 'providers.dart';
import 'widgets/bills_widgets.dart';

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
    final choice = await showChoiceSheet<String>(
      context,
      title: i.name,
      options: [
        ChoiceOption(
          value: 'amount',
          label: t.obEditAmount,
          icon: LucideIcons.banknote,
        ),
        if (i.kind != 'card_statement')
          ChoiceOption(
            value: 'edit',
            label: t.obEditDetails,
            icon: LucideIcons.pencil,
          ),
        if (status == 'pending' || status == 'overdue') ...[
          ChoiceOption(
            value: 'paid',
            label: t.obMarkPaid,
            icon: LucideIcons.circleCheck,
          ),
          ChoiceOption(
            value: 'skipped',
            label: t.obSkip,
            icon: LucideIcons.skipForward,
          ),
        ] else
          ChoiceOption(
            value: 'pending',
            label: t.obReopen,
            icon: LucideIcons.rotateCcw,
          ),
        if (i.kind != 'card_statement')
          ChoiceOption(
            value: 'stop',
            label: t.obStop,
            icon: LucideIcons.circleStop,
            destructive: true,
          ),
      ],
    );
    if (choice == null) return;
    if (choice == 'edit') {
      if (mounted) context.push('$obligationFormPath?id=${i.obligationId}');
      return;
    }
    if (choice == 'stop') {
      if (!mounted) return;
      final sure = await showCupertinoDialog<bool>(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          content: Text(t.obStopConfirm(i.name)),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(t.cancel),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(t.obStop),
            ),
          ],
        ),
      );
      if (sure == true) {
        await _run(() => repo.stopObligation(i.obligationId));
      }
      return;
    }
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
    final muted = AppTokens.muted.resolveFrom(context);

    return CupertinoPageScaffold(
      backgroundColor: AppTokens.bg.resolveFrom(context),
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: Text(t.tabObligations),
            backgroundColor: AppTokens.bg.resolveFrom(context),
            border: null,
            trailing: CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: const Size(44, 44),
              onPressed: () => context.push(obligationFormPath),
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
                    semanticLabel: t.obAddHint,
                  ),
                ),
              ),
            ),
          ),
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
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: PillSegments<ObSection>(
                value: _section,
                onChanged: (v) => setState(() => _section = v),
                labels: {
                  ObSection.upcoming: t.obSegUpcoming,
                  ObSection.overdue: t.obSegOverdue,
                  ObSection.history: t.obSegHistory,
                },
              ),
            ),
          ),
          ...data.when(
            loading: () => [
              const SkeletonSliver(heights: [150, 200, 150]),
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
              final committed = committedHalalas(rows);
              Widget pad(Widget child) => SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: child,
                ),
              );
              return [
                for (final s in suggestions)
                  pad(
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t.obSuggestTitle(s.name),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppTokens.text.resolveFrom(context),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 16,
                            children: [
                              CupertinoButton(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(44, 44),
                                onPressed: () =>
                                    _run(() => repo.confirmMatch(s.id)),
                                child: Text(
                                  t.obConfirm,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AppTokens.accent.resolveFrom(
                                      context,
                                    ),
                                  ),
                                ),
                              ),
                              CupertinoButton(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(44, 44),
                                onPressed: () =>
                                    _run(() => repo.rejectMatch(s.id)),
                                child: Text(
                                  t.obNotThis,
                                  style: TextStyle(color: muted),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                if (_section == ObSection.upcoming)
                  pad(
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t.obCommitted,
                            style: TextStyle(fontSize: 14, color: muted),
                          ),
                          const SizedBox(height: 4),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: AlignmentDirectional.centerStart,
                            child: _amount(
                              committed,
                              arabic,
                              TextStyle(
                                fontSize: 34,
                                fontWeight: FontWeight.w800,
                                color: AppTokens.text.resolveFrom(context),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          _line(
                            t.obMonthCommitted,
                            t.obMonthCommittedNote,
                            committedMonth,
                            arabic,
                          ),
                          if (spend != null) ...[
                            const SizedBox(height: 10),
                            _line(
                              t.obMonthOther,
                              t.obMonthTitle,
                              (spend - paidMonth).clamp(0, 1 << 40),
                              arabic,
                            ),
                          ],
                        ],
                      ),
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
                  // One card per month so "this month" and "next month" never blur together.
                  for (final g in groupByMonth(rows, today)) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                        child: Text(
                          _groupTitle(g.monthStart, today, arabic, t),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: muted,
                          ),
                        ),
                      ),
                    ),
                    pad(
                      RowsCard(
                        children: [
                          for (final i in g.items) _row(i, today, arabic, t),
                        ],
                      ),
                    ),
                  ]
                else
                  pad(
                    RowsCard(
                      children: [
                        for (final i in rows) _row(i, today, arabic, t),
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

  Widget _line(String title, String note, int halalas, bool arabic) {
    final muted = AppTokens.muted.resolveFrom(context);
    final text = AppTokens.text.resolveFrom(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: text,
                ),
              ),
              Text(note, style: TextStyle(fontSize: 12, color: muted)),
            ],
          ),
        ),
        const SizedBox(width: 12),
        _amount(
          halalas,
          arabic,
          TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: text),
        ),
      ],
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

  Widget _amount(int halalas, bool arabic, TextStyle style) => Directionality(
    textDirection: TextDirection.ltr,
    child: Text(formatSar(halalas, arabic: arabic), style: style),
  );

  Widget _row(
    ObligationInstance i,
    DateTime today,
    bool arabic,
    AppLocalizations t,
  ) {
    final status = effectiveStatus(i, today);
    final label = switch (status) {
      'paid' => t.obStatusPaid,
      'overdue' => t.obStatusOverdue,
      'skipped' => t.obStatusSkipped,
      _ => t.obStatusPending,
    };
    final soon = status == 'pending' && i.dueDate.difference(today).inDays <= 7;
    final tone = switch (status) {
      'paid' => PillTone.ok,
      'overdue' => PillTone.danger,
      'skipped' => PillTone.muted,
      _ => soon ? PillTone.warn : PillTone.muted,
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
    return ObligationRow(
      onTap: () => _rowActions(i, status),
      name: i.name,
      kind: i.kind,
      statusLabel: label,
      tone: tone,
      detail: [
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
    );
  }
}
