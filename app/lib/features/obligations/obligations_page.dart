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
import '../../ui/app_form.dart';
import '../../ui/bottom_inset.dart';
import '../../ui/empty_state.dart';
import '../../ui/grow_in.dart';
import '../../ui/header_button.dart';
import '../../ui/skeleton.dart';
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
    final repo = ref.read(dataRepositoryProvider);
    final muted = AppTokens.muted.resolveFrom(context);
    // Text on the gold hero: ink in both modes.
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
              key: const ValueKey('obligations-add'),
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
              // One screen (owner's design 2026-11-19): the hero, then one list with each bill's status.
              final rows = billsList(all, today);
              final overdue = rows
                  .where(
                    (i) =>
                        effectiveStatus(i, today) == 'overdue' ||
                        isLeftover(i, today),
                  )
                  .length;
              final summary = summarizeCycle(rows, today);
              Widget pad(Widget child) => SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: child,
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
              final historyButton = pad(
                SecondaryButton(
                  key: const ValueKey('bills-history'),
                  label: t.obSegHistory,
                  icon: LucideIcons.history,
                  onPressed: () => context.push(billsHistoryPath),
                ),
              );
              if (rows.isEmpty) {
                return [
                  ...suggestionCards,
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      // good news only when bills exist; a new account with none is still waiting
                      art: all.any((i) => !i.isSuggestion)
                          ? EmptyArtKind.done
                          : EmptyArtKind.waiting,
                      title: t.obEmptyUpcoming,
                    ),
                  ),
                  historyButton,
                ];
              }
              final monthLabel = monthName(currentCycle(today), arabic: arabic);
              final paidLine = t.obCyclePaid(
                ltrIsolate(formatSar(summary.paidHalalas, arabic: arabic)),
                ltrIsolate(formatSar(summary.totalHalalas, arabic: arabic)),
                summary.paidCount.toString(),
                summary.count.toString(),
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
                          child: Directionality(
                            textDirection: TextDirection.ltr,
                            child: Text(
                              formatSar(summary.stillHalalas, arabic: arabic),
                              style: TextStyle(
                                fontSize: 34,
                                fontWeight: FontWeight.w800,
                                color: ink,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _CycleBar(
                          done: summary.paidHalalas,
                          total: summary.totalHalalas,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          overdue > 0
                              ? '$paidLine · ${t.obOverdueCount(overdue)}'
                              : paidLine,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                pad(
                  RowsCard(
                    key: const ValueKey('bills-list'),
                    children: [
                      for (final i in rows)
                        billRow(context, i, today, arabic, t),
                    ],
                  ),
                ),
                historyButton,
              ];
            },
          ),
          const BottomInset(),
        ],
      ),
    );
  }
}

/// One bill with its own status: Paid, Overdue, Due today / tomorrow / in N days (the last week, warn tone), or
/// Pending. Tapping it opens the bill sheet. Shared by Bills and Bill history.
Widget billRow(
  BuildContext context,
  ObligationInstance i,
  DateTime today,
  bool arabic,
  AppLocalizations t,
) {
  final status = effectiveStatus(i, today);
  final days = daysUntilDue(i, today);
  final soon = status == 'pending' && days <= billsSoonDays;
  final label = switch (status) {
    'paid' => t.obStatusPaid,
    'overdue' => t.obStatusOverdue,
    'skipped' => t.obStatusSkipped,
    _ when isLeftover(i, today) => t.obStatusOverdue,
    _ when soon =>
      days <= 0
          ? t.obDueToday
          : days == 1
          ? t.obDueTomorrow
          : t.obDueInDays(days),
    _ => t.obStatusPending,
  };
  final tone = switch (status) {
    'paid' => PillTone.ok,
    'overdue' => PillTone.danger,
    'skipped' => PillTone.muted,
    _ when isLeftover(i, today) => PillTone.danger,
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
