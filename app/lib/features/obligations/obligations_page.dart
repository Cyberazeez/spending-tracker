import 'package:flutter/cupertino.dart';

import '../../ui/confirm_sheet.dart';

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
import '../../ui/grow_in.dart';
import '../../ui/header_button.dart';
import '../../ui/skeleton.dart';
import '../../ui/chevron.dart';
import '../../ui/tokens.dart';
import 'bill_sheet.dart';
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
  bool _nextOpen = false;

  Future<void> _run(Future<void> Function() action) async {
    final t = AppLocalizations.of(context);
    try {
      await action();
    } catch (_) {
      if (!mounted) return;
      await showNoticeSheet(context, title: t.obSaveFailed);
    } finally {
      if (mounted) {
        ref.invalidate(obligationsProvider);
        ref.invalidate(monthSpendProvider);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final arabic = ref.watch(localeProvider).languageCode == 'ar';
    final today = riyadhToday(ref.watch(clockProvider)());
    final data = ref.watch(obligationsProvider);
    final overdueCount = data.value == null
        ? 0
        : overdueRows(data.value!, today).length;
    final repo = ref.read(dataRepositoryProvider);
    final muted = AppTokens.muted.resolveFrom(context);
    // Text on the gold hero and the gold notice: ink in both modes.
    final ink = AppTokens.onTint.resolveFrom(context);

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
            trailing: HeaderIconButton(
              onPressed: () => context.push(addBillPath),
              fill: AppTokens.gold.resolveFrom(context),
              icon: LucideIcons.plus,
              iconColor: AppTokens.onTint.resolveFrom(context),
              semanticLabel: t.obAddHint,
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
                badges: {ObSection.overdue: overdueCount},
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
                child: LoadFailedCard(
                  onRetry: () => ref.invalidate(obligationsProvider),
                ),
              ),
            ],
            data: (all) {
              final suggestions = all.where((i) => i.isSuggestion).toList();
              final cycle = currentCycle(today);
              final thisRows = cycleRows(all, cycle, today);
              final nextRows = cycleRows(
                all,
                nextCycle(today),
                today,
              ).where((i) => effectiveStatus(i, today) != 'paid').toList();
              final late = overdueRows(all, today);
              final before = late.where((i) => isLeftover(i, today)).toList();
              final summary = summarizeCycle(thisRows, today);
              final rows = _section == ObSection.overdue
                  ? late
                  : inSection(all, ObSection.history, today);
              Widget pad(Widget child) => SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: child,
                ),
              );
              Widget heading(String title) => SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: muted,
                    ),
                  ),
                ),
              );
              // "Next month" can be opened and closed again: the heading is the button, with a chevron that shows the state.
              Widget collapsibleHeading(String title) => SliverToBoxAdapter(
                child: Semantics(
                  button: true,
                  expanded: _nextOpen,
                  label: title,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => _nextOpen = !_nextOpen),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: ExcludeSemantics(
                              child: Text(
                                title,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: muted,
                                ),
                              ),
                            ),
                          ),
                          Icon(
                            _nextOpen
                                ? LucideIcons.chevronUp
                                : LucideIcons.chevronDown,
                            size: 16,
                            color: muted,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
              final suggestionCards = [
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
                                onPressed: () async {
                                  final ok = await confirmMarkPaid(
                                    context,
                                    ref,
                                    s,
                                    arabic: arabic,
                                  );
                                  if (ok == true) {
                                    await _run(() => repo.confirmMatch(s.id));
                                  } else if (ok == false) {
                                    await _run(() => repo.rejectMatch(s.id));
                                  }
                                },
                                child: Text(
                                  t.obConfirm,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AppTokens.accentText.resolveFrom(
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
              ];
              if (_section != ObSection.upcoming) {
                return [
                  ...suggestionCards,
                  if (rows.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: EmptyState(
                        icon: CupertinoIcons.calendar,
                        title: _section == ObSection.overdue
                            ? t.obEmptyOverdue
                            : t.obEmptyHistory,
                      ),
                    )
                  else if (_section == ObSection.history)
                    for (final g in groupByCycle(rows)) ...[
                      heading(
                        '${monthName(g.monthStart, arabic: arabic)} ${ltrIsolate(g.monthStart.year.toString())}',
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
              }
              final monthLabel = monthName(cycle, arabic: arabic);
              final nextTotal = nextRows.fold<int>(
                0,
                (sum, i) => sum + (i.expectedHalalas ?? 0),
              );
              return [
                ...suggestionCards,
                pad(
                  AppCard(
                    key: const ValueKey('bills-hero'),
                    color: AppTokens.gold.resolveFrom(context),
                    radius: AppTokens.radiusHero,
                    shadow: const Offset(5, 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.obCycleStill(monthLabel),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: ink,
                          ),
                        ),
                        const SizedBox(height: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: AlignmentDirectional.centerStart,
                          child: _amount(
                            summary.stillHalalas,
                            arabic,
                            TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.w800,
                              color: ink,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _CycleBar(
                          done: summary.paidHalalas,
                          total: summary.totalHalalas,
                        ),
                        const SizedBox(height: 10),
                        Directionality(
                          textDirection: Directionality.of(context),
                          child: Text(
                            t.obCyclePaid(
                              ltrIsolate(
                                formatSar(summary.paidHalalas, arabic: arabic),
                              ),
                              ltrIsolate(
                                formatSar(summary.totalHalalas, arabic: arabic),
                              ),
                              summary.paidCount.toString(),
                              summary.count.toString(),
                            ),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (before.isNotEmpty)
                  pad(
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => _section = ObSection.overdue),
                      child: AppCard(
                        pressable: true,
                        color: AppTokens.warnBg.resolveFrom(context),
                        padding: EdgeInsets.zero,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                LucideIcons.triangleAlert,
                                size: 20,
                                color: AppTokens.onTint.resolveFrom(context),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      t.obUnpaidBefore(before.length),
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: AppTokens.onTint.resolveFrom(
                                          context,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      before.map((i) => i.name).join(', '),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: AppTokens.onTint.resolveFrom(
                                          context,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              ForwardChevron(
                                size: 16,
                                color: AppTokens.onTint.resolveFrom(context),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                if (thisRows.isEmpty && nextRows.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      icon: CupertinoIcons.calendar,
                      title: t.obEmptyUpcoming,
                    ),
                  )
                else ...[
                  if (thisRows.isNotEmpty) ...[
                    heading(t.obGroupThis(monthLabel)),
                    pad(
                      RowsCard(
                        children: [
                          for (final i in thisRows) _row(i, today, arabic, t),
                        ],
                      ),
                    ),
                  ],
                  if (nextRows.isNotEmpty) ...[
                    collapsibleHeading(
                      t.obGroupNext(
                        monthName(nextCycle(today), arabic: arabic),
                      ),
                    ),
                    pad(
                      _nextOpen
                          ? RowsCard(
                              children: [
                                for (final i in nextRows)
                                  _row(i, today, arabic, t),
                              ],
                            )
                          : GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => setState(() => _nextOpen = true),
                              child: AppCard(
                                pressable: true,
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            t.obNextSummary(nextRows.length),
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                              color: AppTokens.text.resolveFrom(
                                                context,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            t.obNextNote(
                                              ltrIsolate(
                                                formatSar(
                                                  nextTotal,
                                                  arabic: arabic,
                                                ),
                                              ),
                                            ),
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: muted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                    ),
                  ],
                ],
              ];
            },
          ),
          const BottomInset(),
        ],
      ),
    );
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
    // Only the amount, in bold: what was paid, else what is expected.
    final shown = status == 'paid' && i.actualHalalas != null
        ? i.actualHalalas
        : i.expectedHalalas;
    final amount = shown != null
        ? ltrIsolate(formatSar(shown, arabic: arabic))
        : '';
    return ObligationRow(
      onTap: () => showBillSheet(
        context,
        instance: i,
        status: status,
        statusLabel: label,
        tone: tone,
        today: today,
      ),
      name: i.name,
      kind: i.kind,
      statusLabel: label,
      tone: tone,
      detail: amount,
    );
  }
}

/// An outlined progress bar on the gold hero: white track, emerald fill from the leading edge (the paid part).
class _CycleBar extends StatelessWidget {
  const _CycleBar({required this.done, required this.total});
  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    final share = total <= 0 ? 0.0 : (done / total).clamp(0.0, 1.0);
    final ink = AppTokens.onTint.resolveFrom(context);
    return Semantics(
      label: '${(share * 100).round()}%',
      child: Container(
        height: 14,
        decoration: BoxDecoration(
          // White in both modes: the bar sits on gold.
          color: const Color(0xFFFFFFFF),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: ink, width: AppTokens.outlineThin),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(5),
          // The paid share grows from empty each time Bills comes into view.
          child: GrowIn(
            builder: (context, g) => LayoutBuilder(
              builder: (context, box) => Stack(
                children: [
                  PositionedDirectional(
                    start: 0,
                    top: 0,
                    bottom: 0,
                    width: box.maxWidth * (share * g).clamp(0.0, 1.0),
                    child: DecoratedBox(
                      key: const ValueKey('cycle-bar-fill'),
                      decoration: BoxDecoration(
                        color: AppTokens.accent.resolveFrom(context),
                        border: share > 0 && share < 1
                            ? BorderDirectional(
                                end: BorderSide(
                                  color: ink,
                                  width: AppTokens.outlineThin,
                                ),
                              )
                            : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
