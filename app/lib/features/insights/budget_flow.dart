import 'package:flutter/cupertino.dart';

import '../../ui/confirm_sheet.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/amount_sheet.dart';
import 'metrics.dart';
import 'providers.dart';

Future<int?> askBudgetLimit(
  BuildContext context,
  int? current, {
  String? subtitle,
  bool monthly = true,
}) {
  final t = AppLocalizations.of(context);
  return showAmountSheet(
    context,
    title: t.insBudgetPrompt,
    subtitle: subtitle,
    initialHalalas: current,
    suggestionsHalalas: [
      for (final v
          in monthly
              ? const [3000, 5000, 8000, 10000, 15000]
              : const [200, 500, 1000, 2000, 3000])
        v * 100,
    ],
    maxHalalas: maxBudgetHalalas,
    invalidText: t.insBudgetInvalid,
  );
}

Future<void> saveBudgetChange(
  BuildContext context,
  WidgetRef ref,
  Future<void> Function() action,
) async {
  final t = AppLocalizations.of(context);
  try {
    await action();
  } catch (_) {
    if (!context.mounted) return;
    await showNoticeSheet(context, title: t.obSaveFailed);
  } finally {
    if (context.mounted) {
      ref.invalidate(budgetsProvider);
      ref.invalidate(monthlyBudgetProvider);
    }
  }
}

/// Sets, changes or removes the monthly budget in one sheet: the amount, presets, Save, and "Remove the budget"
/// while one is set.
Future<void> showMonthlyBudgetFlow(
  BuildContext context,
  WidgetRef ref, {
  int? current,
}) async {
  final t = AppLocalizations.of(context);
  current ??= ref.read(monthlyBudgetProvider).value;
  final repo = ref.read(dataRepositoryProvider);
  final r = await showAmountSheetOrRemove(
    context,
    title: t.insMonthlyBudget,
    initialHalalas: current,
    suggestionsHalalas: const [400000, 500000, 600000, 800000],
    maxHalalas: maxBudgetHalalas,
    invalidText: t.insBudgetInvalid,
    // Only a budget that exists can be removed.
    removeLabel: current == null ? null : t.insBudgetRemoveThe,
  );
  if (!context.mounted) return;
  switch (r) {
    case AmountSet(:final halalas):
      if (halalas != current) {
        await saveBudgetChange(
          context,
          ref,
          () => repo.setMonthlyBudget(halalas),
        );
      }
    case AmountRemoved():
      if (current != null) {
        await saveBudgetChange(context, ref, () => repo.setMonthlyBudget(null));
      }
    case null:
      break;
  }
}
