import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/confirm_sheet.dart';
import '../insights/providers.dart';
import 'providers.dart';

/// Asks first, then removes the transaction from everything (budgets, insights, widget numbers). It cannot be undone
/// from the app, so the question says so.
/// Asks, then deletes. True when the transaction was deleted.
Future<bool> confirmAndDeleteTxn(
  BuildContext context,
  WidgetRef ref,
  Txn txn,
) async {
  final t = AppLocalizations.of(context);
  final ok = await showConfirmSheet(
    context,
    title: t.txDeleteTitle,
    message: t.txDeleteBody,
    confirmLabel: t.txDelete,
    destructive: true,
  );
  if (ok != true) return false;
  try {
    await ref.read(dataRepositoryProvider).deleteTransaction(txn.id);
  } catch (_) {
    if (context.mounted) {
      await showNoticeSheet(context, title: t.txDeleteFailed);
    }
    return false;
  }
  ref.invalidate(transactionsProvider);
  ref.invalidate(insightsProvider);
  ref.invalidate(todaySpendProvider);
  ref.invalidate(budgetsProvider);
  return true;
}
