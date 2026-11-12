import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/banks.dart';
import '../../core/format.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/app_form.dart';
import '../../ui/app_sheet.dart';
import '../../ui/press.dart';
import '../../ui/settings_group.dart' show appSwitch;
import '../../ui/sheet_frame.dart';
import '../../ui/tokens.dart';
import '../account/account_providers.dart';
import '../home/category_groups.dart';
import '../home/group_style.dart';
import '../obligations/widgets/bills_widgets.dart' show PillSegments;
import 'providers.dart';

/// The Activity filter: date (this month, last month, a custom range), a category group, one bank account or card,
/// "No category only" and "Include transfers between my accounts". Changes apply when "Show N" is tapped; N counts
/// the matching transactions as the filter is changed.
Future<void> showTxFilterSheet(BuildContext context, WidgetRef ref) =>
    showAppSheet<void>(context: context, builder: (_) => const _FilterSheet());

class _FilterSheet extends ConsumerStatefulWidget {
  const _FilterSheet();

  @override
  ConsumerState<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<_FilterSheet> {
  late TxFilter _f = ref.read(txFilterProvider);
  CategoryGroup? _group;
  int? _count;
  int _ask = 0; // only the newest count is shown
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    // The chosen group is kept as its category ids; find which group they are.
    final ids = _f.categoryIds;
    if (ids != null) {
      final cats = ref.read(categoriesProvider).value ?? const <Category>[];
      for (final g in CategoryGroup.values) {
        final gIds = _idsOf(g, cats);
        if (gIds.length == ids.length && gIds.every(ids.contains)) _group = g;
      }
    }
    _recount();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  List<String> _idsOf(CategoryGroup g, List<Category> cats) => [
    for (final c in cats)
      if (groupOf(c.name) == g) c.id,
  ];

  void _change(TxFilter f) {
    _ask++; // a count still running for the old filter is no longer shown
    setState(() {
      _f = f;
      _count = null;
    });
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), _recount);
  }

  Future<void> _recount() async {
    final ask = ++_ask;
    try {
      final n = await ref.read(dataRepositoryProvider).countTransactions(_f);
      if (mounted && ask == _ask) setState(() => _count = n);
    } catch (_) {
      if (mounted && ask == _ask) setState(() => _count = null);
    }
  }

  Future<DateTime?> _pickDay(DateTime initial) async {
    var picked = initial;
    final t = AppLocalizations.of(context);
    return showAppSheet<DateTime>(
      context: context,
      builder: (ctx) => SheetFrame(
        title: t.filterCustom,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 216,
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: initial,
                  maximumDate: DateTime.now(),
                  onDateTimeChanged: (d) => picked = d,
                ),
              ),
              const SizedBox(height: 8),
              PrimaryButton(
                label: t.done,
                onPressed: () => Navigator.pop(ctx, picked),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final arabic = ref.watch(localeProvider).languageCode == 'ar';
    final cats = ref.watch(categoriesProvider).value ?? const <Category>[];
    final accounts = ref.watch(ownAccountsProvider).value ?? const [];
    final text = AppTokens.text.resolveFrom(context);
    final now = DateTime.now();

    Widget heading(String s) => Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 8),
      child: Text(
        s,
        style: TextStyle(
          color: text,
          fontSize: 15,
          fontWeight: FontWeight.w800,
        ),
      ),
    );

    Widget switchRow(String label, bool value, ValueChanged<bool> onChanged) =>
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: text,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              appSwitch(context, value: value, onChanged: onChanged),
            ],
          ),
        );

    final groups = [
      for (final g in CategoryGroup.values)
        if (_idsOf(g, cats).isNotEmpty) g,
    ];
    final period = _f.period == TxPeriod.all ? TxPeriod.thisMonth : _f.period;

    return SheetFrame(
      title: t.filterTitle,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            heading(t.filterDate),
            PillSegments<TxPeriod>(
              value: period,
              labels: {
                TxPeriod.thisMonth: t.filterThisMonth,
                TxPeriod.lastMonth: t.filterLastMonth,
                TxPeriod.custom: t.filterCustom,
              },
              onChanged: (p) {
                if (p != TxPeriod.custom) {
                  _change(_f.copyWith(period: p));
                  return;
                }
                final start = DateTime(now.year, now.month, 1);
                _change(
                  _f.copyWith(
                    period: TxPeriod.custom,
                    from: _f.from ?? start,
                    to: _f.to ?? DateTime(now.year, now.month, now.day),
                  ),
                );
              },
            ),
            if (period == TxPeriod.custom) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: FieldButton(
                      label: '${t.filterFrom}: ${formatDay(_f.from ?? now)}',
                      onPressed: () async {
                        final d = await _pickDay(_f.from ?? now);
                        if (d == null) return;
                        final to = _f.to ?? d;
                        _change(
                          _f.copyWith(from: d, to: to.isBefore(d) ? d : to),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FieldButton(
                      label: '${t.filterTo}: ${formatDay(_f.to ?? now)}',
                      onPressed: () async {
                        final d = await _pickDay(_f.to ?? now);
                        if (d == null) return;
                        final from = _f.from ?? d;
                        _change(
                          _f.copyWith(to: d, from: from.isAfter(d) ? d : from),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
            heading(t.filterCategory),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final g in groups)
                  _SheetChip(
                    label: groupLabel(t, g),
                    selected: _group == g,
                    fill: AppTokens.gold.resolveFrom(context),
                    onTap: () {
                      final pick = _group == g ? null : g;
                      setState(() => _group = pick);
                      _change(
                        _f.copyWith(
                          categoryIds: pick == null ? null : _idsOf(pick, cats),
                          categoryId: null,
                        ),
                      );
                    },
                  ),
              ],
            ),
            if (accounts.isNotEmpty) ...[
              heading(t.filterBankCard),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _SheetChip(
                    label: t.filterAllAccounts,
                    selected: _f.accountLast4 == null,
                    onTap: () => _change(_f.copyWith(accountLast4: null)),
                  ),
                  for (final a in accounts)
                    _SheetChip(
                      label: a.kind == 'wallet'
                          ? bankDisplayName(a.bank, arabic: arabic)
                          : '•••• ${a.last4}',
                      selected: _f.accountLast4 == a.last4,
                      onTap: () => _change(_f.copyWith(accountLast4: a.last4)),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            switchRow(
              t.filterNoCategoryOnly,
              _f.uncategorizedOnly,
              (v) => _change(
                _f.copyWith(
                  uncategorizedOnly: v,
                  categoryId: v ? null : _f.categoryId,
                  aiOnly: v ? false : _f.aiOnly,
                ),
              ),
            ),
            switchRow(
              t.filterIncludeTransfers,
              !_f.hideInternal,
              (v) => _change(_f.copyWith(hideInternal: !v)),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: SecondaryButton(
                    label: t.filterReset,
                    onPressed: () {
                      setState(() => _group = null);
                      _change(TxFilter(query: _f.query));
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: PrimaryButton(
                    key: const ValueKey('filter-show'),
                    label: _count == null
                        ? t.filterTitle
                        : t.filterShow(_count!),
                    onPressed: () {
                      ref.read(txFilterProvider.notifier).set(_f);
                      Navigator.pop(context);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A chip in the filter sheet: [fill] (emerald by default) when chosen, white otherwise.
class _SheetChip extends StatelessWidget {
  const _SheetChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.fill,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? fill;

  @override
  Widget build(BuildContext context) {
    final on = fill ?? AppTokens.accent.resolveFrom(context);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: const Size(44, 44),
        pressedOpacity: 1,
        onPressed: onTap,
        child: PressShadow(
          decoration: BoxDecoration(
            color: selected ? on : AppTokens.card.resolveFrom(context),
            borderRadius: BorderRadius.circular(20),
            border: outlineOf(context, width: AppTokens.outlineThin),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            child: Text(
              label,
              style: TextStyle(
                color: selected
                    ? AppTokens.onTint.resolveFrom(context)
                    : AppTokens.text.resolveFrom(context),
                fontSize: 14,
                fontWeight: FontWeight.w700,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
