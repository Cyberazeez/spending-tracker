import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/format.dart';
import '../../core/models.dart';
import '../../core/money.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../router.dart';
import '../../ui/amount_sheet.dart';
import '../../ui/app_form.dart';
import '../../ui/app_sheet.dart';
import '../../ui/choice_sheet.dart';
import '../../ui/confirm_sheet.dart';
import '../../ui/icon_tile.dart';
import '../../ui/settings_group.dart' show appSwitch;
import '../../ui/sheet_frame.dart';
import '../../ui/theme.dart';
import '../../ui/tokens.dart';
import '../insights/metrics.dart' show maxBudgetHalalas;
import '../transactions/providers.dart';
import 'providers.dart';
import 'widgets/bills_widgets.dart';

/// The sheet of one bill: what it is and when, the amount (tap to change it), its settings (amount type, how
/// often, due day, reminder, active) saved as they change, Mark as paid, Skip this month and Stop this bill.
Future<void> showBillSheet(
  BuildContext context, {
  required ObligationInstance instance,
  required String status,
  required String statusLabel,
  required PillTone tone,
  required DateTime today,
}) => showAppSheet<void>(
  context: context,
  builder: (_) => _BillSheet(
    i: instance,
    status: status,
    statusLabel: statusLabel,
    tone: tone,
    today: today,
  ),
);

/// Asks before marking a bill paid: the bill's tile, and the payment that looks like it when the server found one.
/// [onNotThis] (the "Not this payment" button) is offered for a suggested payment. True: mark it paid.
Future<bool?> confirmMarkPaid(
  BuildContext context,
  WidgetRef ref,
  ObligationInstance i, {
  required bool arabic,
}) {
  final t = AppLocalizations.of(context);
  final style = kindStyle(i.kind);
  final suggested = i.isSuggestion;
  String message;
  if (suggested && i.actualHalalas != null) {
    final amount = ltrIsolate(formatSar(i.actualHalalas!, arabic: arabic));
    final txn = (ref.read(transactionsProvider).value ?? const <Txn>[])
        .where((x) => x.id == i.transactionId)
        .firstOrNull;
    message = txn == null
        ? t.bsPaidMatchNoDate(amount)
        : t.bsPaidMatch(
            amount,
            formatDay(txn.occurredAt.add(const Duration(hours: 3))),
          );
  } else {
    message = t.bsPaidPlain(
      i.expectedHalalas == null
          ? '—'
          : ltrIsolate(formatSar(i.expectedHalalas!, arabic: arabic)),
      formatDay(i.dueDate),
    );
  }
  return showConfirmSheet(
    context,
    title: t.bsPaidTitle(i.name),
    message: message,
    confirmLabel: t.bsYesPaid,
    cancelLabel: suggested ? t.bsNotThis : null,
    icon: style.icon,
    iconColor: style.color,
  );
}

class _BillSheet extends ConsumerStatefulWidget {
  const _BillSheet({
    required this.i,
    required this.status,
    required this.statusLabel,
    required this.tone,
    required this.today,
  });

  final ObligationInstance i;
  final String status;
  final String statusLabel;
  final PillTone tone;
  final DateTime today;

  @override
  ConsumerState<_BillSheet> createState() => _BillSheetState();
}

class _BillSheetState extends ConsumerState<_BillSheet> {
  ObligationDef? _def;

  /// A save or an action is running: further taps wait, so nothing is sent twice and nothing pops twice.
  bool _busy = false;

  ObligationInstance get i => widget.i;
  bool get _open => widget.status == 'pending' || widget.status == 'overdue';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await ref
          .read(dataRepositoryProvider)
          .obligation(i.obligationId);
      if (mounted) setState(() => _def = d);
    } catch (_) {
      // The settings simply stay hidden; the bill's actions still work.
    }
  }

  /// Refreshes the Bills lists. Taken from the container, so it still works after the sheet was closed.
  void Function() _refresher() {
    final c = ProviderScope.containerOf(context, listen: false);
    return () {
      c.invalidate(obligationsProvider);
      c.invalidate(monthSpendProvider);
    };
  }

  /// Closes this sheet, only while it is still the top route (it may have been dismissed meanwhile).
  void _close(ModalRoute<Object?>? route) {
    if (mounted && route != null && route.isCurrent) {
      Navigator.of(context).pop();
    }
  }

  /// Saves the bill's settings with one change; the server rebuilds its open months. A change of how often or
  /// which day moves this month's due date (or removes it), so the sheet closes and the list shows the new one.
  Future<void> _save(ObligationDef d, {bool close = false}) async {
    if (_busy) return;
    final t = AppLocalizations.of(context);
    final refresh = _refresher();
    final route = ModalRoute.of(context);
    final before = _def;
    setState(() {
      _def = d;
      _busy = true;
    });
    try {
      await ref.read(dataRepositoryProvider).saveObligation(i.obligationId, d);
      refresh();
      if (close) _close(route);
    } catch (_) {
      if (!mounted) return;
      setState(() => _def = before);
      await showNoticeSheet(context, title: t.obSaveFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Runs an action on the bill, then closes the sheet.
  Future<void> _act(Future<void> Function() action) async {
    if (_busy) return;
    final t = AppLocalizations.of(context);
    final refresh = _refresher();
    final route = ModalRoute.of(context);
    setState(() => _busy = true);
    try {
      await action();
    } catch (_) {
      if (mounted) await showNoticeSheet(context, title: t.obSaveFailed);
      return;
    } finally {
      refresh();
      if (mounted) setState(() => _busy = false);
    }
    _close(route);
  }

  Future<void> _markPaid(bool arabic) async {
    if (_busy) return;
    final repo = ref.read(dataRepositoryProvider);
    final ok = await confirmMarkPaid(context, ref, i, arabic: arabic);
    if (!mounted) return;
    if (ok == true) {
      await _act(
        () => i.isSuggestion
            ? repo.confirmMatch(i.id)
            : repo.setInstanceStatus(i.id, 'paid'),
      );
    } else if (ok == false && i.isSuggestion) {
      await _act(() => repo.rejectMatch(i.id));
    }
  }

  Future<void> _stop() async {
    if (_busy) return;
    final t = AppLocalizations.of(context);
    final sure = await showConfirmSheet(
      context,
      title: t.obStopConfirm(i.name),
      confirmLabel: t.obStop,
      destructive: true,
    );
    if (sure == true && mounted) {
      await _act(
        () => ref.read(dataRepositoryProvider).stopObligation(i.obligationId),
      );
    }
  }

  Future<void> _editAmount() async {
    if (_busy) return;
    final t = AppLocalizations.of(context);
    final paid = widget.status == 'paid';
    final current = paid
        ? (i.actualHalalas ?? i.expectedHalalas)
        : i.expectedHalalas;
    final v = await showAmountSheet(
      context,
      title: t.obEditAmountPrompt,
      initialHalalas: current,
      maxHalalas: maxBudgetHalalas,
      invalidText: t.obAmountInvalid,
    );
    if (v == null || !mounted) return;
    await _act(
      () => ref
          .read(dataRepositoryProvider)
          .setInstanceAmount(i.id, v, paid: paid),
    );
  }

  ObligationDef _with(
    ObligationDef d, {
    String? amountType,
    String? frequency,
    int? day,
    int? leadDays,
  }) => ObligationDef(
    id: d.id,
    name: d.name,
    kind: d.kind,
    amountType: amountType ?? d.amountType,
    amountHalalas: d.amountHalalas,
    frequency: frequency ?? d.frequency,
    day: day ?? d.day,
    startMonth: d.startMonth ?? widget.today.month,
    graceDays: d.graceDays,
    leadDays: leadDays ?? d.leadDays,
    active: d.active,
    categoryId: d.categoryId,
    merchantWords: d.merchantWords,
    tolerancePct: d.tolerancePct,
    autoMerchant: d.autoMerchant,
  );

  Future<int?> _pickDay(int current) async {
    final t = AppLocalizations.of(context);
    var picked = current;
    return showAppSheet<int>(
      context: context,
      builder: (ctx) => _PickerSheet(
        title: t.obfDueDay,
        initial: current - 1,
        count: 31,
        label: (n) => '${n + 1}',
        onChanged: (n) => picked = n + 1,
        onDone: () => Navigator.pop(ctx, picked),
        doneLabel: t.done,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final arabic = ref.watch(localeProvider).languageCode == 'ar';
    final media = MediaQuery.of(context);
    final text = AppTokens.text.resolveFrom(context);
    final muted = AppTokens.muted.resolveFrom(context);
    final style = kindStyle(i.kind);
    final late = widget.today.difference(i.dueDate).inDays;
    final when = widget.status == 'overdue' && late > 0
        ? '${t.obDue(formatDay(i.dueDate))} · ${t.bsDaysLate(late)}'
        : t.obDue(formatDay(i.dueDate));
    final shown = widget.status == 'paid' && i.actualHalalas != null
        ? i.actualHalalas
        : i.expectedHalalas;
    // A stopped bill (seen from History) shows no settings: saving any of them would start it again.
    final d = _def?.active == false ? null : _def;
    final stopped = _def?.active == false;

    Widget label(String s) => Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 6),
      child: Text(
        s,
        style: TextStyle(
          color: text,
          fontSize: 14,
          fontWeight: FontWeight.w800,
          decoration: TextDecoration.none,
        ),
      ),
    );

    String freq(String f) => switch (f) {
      'quarterly' => t.obfQuarterly,
      'annual' => t.obfAnnual,
      _ => t.bsEveryMonth,
    };
    String remind(int n) => n == 0 ? t.bsRemindOnDay : t.bsRemindDays(n);

    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        constraints: BoxConstraints(maxHeight: media.size.height * 0.92),
        decoration: BoxDecoration(
          color: AppTokens.bg.resolveFrom(context),
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppTokens.radiusSheet),
          ),
          border: outlineOf(context),
        ),
        child: DefaultTextStyle(
          style: TextStyle(
            color: text,
            fontSize: 15,
            inherit: false,
            fontFamily: appFont,
            fontFamilyFallback: const [riyalFont],
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20, 10, 20, media.padding.bottom + 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppTokens.line
                          .resolveFrom(context)
                          .withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    IconTile(
                      color: style.color,
                      icon: style.icon,
                      size: 56,
                      radius: 16,
                      iconSize: 26,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            i.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: text,
                              fontSize: 21,
                              fontWeight: FontWeight.w800,
                              decoration: TextDecoration.none,
                            ),
                          ),
                          Text(
                            when,
                            style: TextStyle(
                              color: muted,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Shrinks rather than overflow with large text.
                    Flexible(
                      flex: 2,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerEnd,
                        child: StatusPill(
                          label: widget.statusLabel,
                          tone: widget.tone,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // The amount: tap to change this month's (expected, or paid) amount.
                Semantics(
                  button: true,
                  label:
                      '${t.obEditAmount}, ${shown == null ? '—' : formatSar(shown, arabic: arabic)}',
                  excludeSemantics: true,
                  child: GestureDetector(
                    key: const ValueKey('bill-amount'),
                    behavior: HitTestBehavior.opaque,
                    onTap: _editAmount,
                    child: Directionality(
                      textDirection: TextDirection.ltr,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: arabic
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Text(
                          shown == null
                              ? '—'
                              : formatSar(shown, arabic: arabic, symbol: false),
                          style: TextStyle(
                            color: text,
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            decoration: TextDecoration.none,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (d != null) ...[
                  label(t.qaAmountLabel),
                  PillSegments<String>(
                    value: d.amountType,
                    labels: {
                      'fixed': t.obfKindFixed,
                      'estimated': t.obfAmountEstimated,
                    },
                    onChanged: (v) {
                      if (v != d.amountType) {
                        _save(_with(d, amountType: v));
                      }
                    },
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        flex: 5,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            label(t.obfRepeats),
                            FieldButton(
                              key: const ValueKey('bill-repeats'),
                              label: freq(d.frequency),
                              onPressed: () async {
                                final f = await showChoiceSheet<String>(
                                  context,
                                  title: t.obfRepeats,
                                  options: [
                                    for (final f in const [
                                      'monthly',
                                      'quarterly',
                                      'annual',
                                    ])
                                      ChoiceOption(
                                        value: f,
                                        label: freq(f),
                                        selected: f == d.frequency,
                                      ),
                                  ],
                                );
                                if (f != null && f != d.frequency && mounted) {
                                  await _save(
                                    _with(d, frequency: f),
                                    close: true,
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            label(t.obfDueDay),
                            FieldButton(
                              key: const ValueKey('bill-day'),
                              label: '${d.day}',
                              onPressed: () async {
                                final n = await _pickDay(d.day);
                                if (n != null && n != d.day && mounted) {
                                  await _save(_with(d, day: n), close: true);
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  label(t.bsRemindMe),
                  FieldButton(
                    key: const ValueKey('bill-remind'),
                    icon: LucideIcons.bell,
                    label: remind(d.leadDays),
                    onPressed: () async {
                      final n = await showChoiceSheet<int>(
                        context,
                        title: t.bsRemindMe,
                        options: [
                          for (final n in const [0, 1, 2, 3, 5, 7])
                            ChoiceOption(
                              value: n,
                              label: remind(n),
                              selected: n == d.leadDays,
                            ),
                        ],
                      );
                      if (n != null && n != d.leadDays && mounted) {
                        await _save(_with(d, leadDays: n));
                      }
                    },
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          t.bsActive,
                          style: TextStyle(
                            color: text,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                      // Turning it off stops the bill (asks first), like "Stop this bill".
                      appSwitch(
                        context,
                        value: true,
                        onChanged: (on) {
                          if (!on) _stop();
                        },
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 18),
                if (_open)
                  PrimaryButton(
                    key: const ValueKey('bill-paid'),
                    label: t.obMarkPaid,
                    icon: LucideIcons.check,
                    onPressed: () => _markPaid(arabic),
                  )
                else
                  SecondaryButton(
                    key: const ValueKey('bill-reopen'),
                    label: t.obReopen,
                    icon: LucideIcons.rotateCcw,
                    onPressed: () => _act(
                      () => ref
                          .read(dataRepositoryProvider)
                          .setInstanceStatus(i.id, 'pending'),
                    ),
                  ),
                const SizedBox(height: 6),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  spacing: 12,
                  children: [
                    if (_open)
                      _Link(
                        key: const ValueKey('bill-skip'),
                        label: t.bsSkipMonth,
                        color: muted,
                        onTap: () => _act(
                          () => ref
                              .read(dataRepositoryProvider)
                              .setInstanceStatus(i.id, 'skipped'),
                        ),
                      ),
                    if (!stopped)
                      _Link(
                        key: const ValueKey('bill-edit'),
                        label: t.obEditDetails,
                        color: AppTokens.accentText.resolveFrom(context),
                        onTap: () {
                          Navigator.of(context).pop();
                          context.push(
                            '$obligationFormPath?id=${i.obligationId}',
                          );
                        },
                      ),
                    if (!stopped)
                      _Link(
                        key: const ValueKey('bill-stop'),
                        label: t.bsStopBill,
                        color: AppTokens.danger.resolveFrom(context),
                        onTap: _stop,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Link extends StatelessWidget {
  const _Link({
    super.key,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => CupertinoButton(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    minimumSize: const Size(44, 44),
    onPressed: onTap,
    child: Text(
      label,
      style: TextStyle(
        color: color,
        fontSize: 16,
        fontWeight: FontWeight.w800,
        decoration: TextDecoration.none,
      ),
    ),
  );
}

/// A wheel picker in a sheet (the due day).
class _PickerSheet extends StatelessWidget {
  const _PickerSheet({
    required this.title,
    required this.initial,
    required this.count,
    required this.label,
    required this.onChanged,
    required this.onDone,
    required this.doneLabel,
  });

  final String title;
  final int initial;
  final int count;
  final String Function(int) label;
  final ValueChanged<int> onChanged;
  final VoidCallback onDone;
  final String doneLabel;

  @override
  Widget build(BuildContext context) => SheetFrame(
    title: title,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 200,
            child: CupertinoPicker(
              itemExtent: 40,
              scrollController: FixedExtentScrollController(
                initialItem: initial,
              ),
              onSelectedItemChanged: onChanged,
              children: [
                for (var n = 0; n < count; n++) Center(child: Text(label(n))),
              ],
            ),
          ),
          const SizedBox(height: 8),
          PrimaryButton(label: doneLabel, onPressed: onDone),
        ],
      ),
    ),
  );
}
