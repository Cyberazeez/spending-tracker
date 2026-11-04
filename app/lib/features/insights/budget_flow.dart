import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/money.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import 'metrics.dart';
import 'providers.dart';

Future<int?> askBudgetLimit(BuildContext context, int? current) async {
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
    final choice = await showCupertinoModalPopup<String>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(t.insMonthlyBudget),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(ctx, 'set'),
            child: Text(t.insBudgetSet),
          ),
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
