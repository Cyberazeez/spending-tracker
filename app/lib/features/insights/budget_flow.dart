import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/amount_sheet.dart';
import '../../ui/choice_sheet.dart';
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
    if (context.mounted) {
      ref.invalidate(budgetsProvider);
      ref.invalidate(monthlyBudgetProvider);
    }
  }
}

/// Sets, changes or removes the monthly budget. With no budget yet it goes straight to the amount prompt.
Future<void> showMonthlyBudgetFlow(
  BuildContext context,
  WidgetRef ref, {
  int? current,
}) async {
  final t = AppLocalizations.of(context);
  current ??= ref.read(monthlyBudgetProvider).value;
  final repo = ref.read(dataRepositoryProvider);
  if (current != null) {
    final choice = await showChoiceSheet<String>(
      context,
      title: t.insMonthlyBudget,
      options: [
        ChoiceOption(
          value: 'set',
          label: t.insBudgetSet,
          icon: LucideIcons.pencil,
        ),
        ChoiceOption(
          value: 'remove',
          label: t.insBudgetRemove,
          icon: LucideIcons.trash2,
          destructive: true,
        ),
      ],
    );
    if (choice == null || !context.mounted) return;
    if (choice == 'remove') {
      await saveBudgetChange(context, ref, () => repo.setMonthlyBudget(null));
      return;
    }
  }
  final halalas = await askBudgetLimit(context, current);
  if (halalas == null || !context.mounted) return;
  await saveBudgetChange(context, ref, () => repo.setMonthlyBudget(halalas));
}
