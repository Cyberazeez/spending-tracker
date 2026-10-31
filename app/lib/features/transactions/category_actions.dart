import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import 'providers.dart';

/// Lets the owner choose a category for one transaction. If other transactions share the merchant, asks whether
/// to change them too and remembers the choice as a rule for future ones.
Future<void> pickCategory(
  BuildContext context,
  WidgetRef ref,
  Txn txn,
  List<Category> cats,
) async {
  final t = AppLocalizations.of(context);
  final arabic = ref.read(localeProvider).languageCode == 'ar';
  final repo = ref.read(dataRepositoryProvider);

  // `null` = dismissed, `''` = remove the category.
  final picked = await showCupertinoModalPopup<String>(
    context: context,
    builder: (ctx) => CupertinoActionSheet(
      title: Text(t.categoryPickTitle),
      message: txn.merchant == null ? null : Text(txn.merchant!),
      actions: [
        for (final c in cats)
          CupertinoActionSheetAction(
            isDefaultAction: c.id == txn.categoryId,
            onPressed: () => Navigator.pop(ctx, c.id),
            child: Text(c.label(arabic: arabic)),
          ),
        if (txn.categoryId != null)
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, ''),
            child: Text(t.categoryRemove),
          ),
      ],
      cancelButton: CupertinoActionSheetAction(
        onPressed: () => Navigator.pop(ctx),
        child: Text(t.cancel),
      ),
    ),
  );
  if (picked == null || !context.mounted) return;
  if (picked == txn.categoryId) return;

  try {
    if (picked.isEmpty) {
      await repo.setCategory(txn.id, null);
    } else {
      var remember = false;
      var alsoPast = false;
      final norm = txn.merchantNorm;
      if (norm != null && norm.isNotEmpty) {
        remember = true;
        final others = await repo.sameMerchantCount(norm, excludingId: txn.id);
        if (others > 0 && context.mounted) {
          final cat = cats.firstWhere((c) => c.id == picked);
          final choice = await showCupertinoDialog<bool>(
            context: context,
            builder: (ctx) => CupertinoAlertDialog(
              title: Text(t.applyPastTitle(others)),
              content: Text(
                t.applyPastBody(
                  txn.merchant ?? norm,
                  cat.label(arabic: arabic),
                ),
              ),
              actions: [
                CupertinoDialogAction(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(t.applyPastNo),
                ),
                CupertinoDialogAction(
                  isDefaultAction: true,
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(t.applyPastYes),
                ),
              ],
            ),
          );
          if (choice == null) return; // dismissed: do nothing
          alsoPast = choice;
        }
      }
      await repo.setCategory(
        txn.id,
        picked,
        rememberFor: remember ? norm : null,
        alsoPast: alsoPast,
      );
    }
  } catch (_) {
    if (context.mounted) {
      await showCupertinoDialog<void>(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          content: Text(t.categorySaveFailed),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(ctx),
              child: Text(t.done),
            ),
          ],
        ),
      );
    }
  } finally {
    if (context.mounted) ref.invalidate(transactionsProvider);
  }
}

Future<void> showFilterSheet(BuildContext context, WidgetRef ref) async {
  final t = AppLocalizations.of(context);
  final arabic = ref.read(localeProvider).languageCode == 'ar';
  final cats = ref.read(categoriesProvider).value ?? const <Category>[];
  final f = ref.read(txFilterProvider);
  final ctl = ref.read(txFilterProvider.notifier);
  await showCupertinoModalPopup<void>(
    context: context,
    builder: (ctx) => CupertinoActionSheet(
      title: Text(t.filterTitle),
      actions: [
        CupertinoActionSheetAction(
          onPressed: () {
            ctl.set(f.copyWith(categoryId: null, uncategorizedOnly: false));
            Navigator.pop(ctx);
          },
          child: Text(t.filterAll),
        ),
        CupertinoActionSheetAction(
          onPressed: () {
            ctl.set(f.copyWith(categoryId: null, uncategorizedOnly: true));
            Navigator.pop(ctx);
          },
          child: Text(t.filterUncategorized),
        ),
        for (final c in cats)
          CupertinoActionSheetAction(
            onPressed: () {
              ctl.set(f.copyWith(categoryId: c.id, uncategorizedOnly: false));
              Navigator.pop(ctx);
            },
            child: Text(c.label(arabic: arabic)),
          ),
        CupertinoActionSheetAction(
          onPressed: () {
            ctl.set(f.copyWith(hideInternal: !f.hideInternal));
            Navigator.pop(ctx);
          },
          child: Text(
            f.hideInternal ? t.filterShowInternal : t.filterHideInternal,
          ),
        ),
        if (f.isActive)
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              ctl.clear();
              Navigator.pop(ctx);
            },
            child: Text(t.filterClear),
          ),
      ],
      cancelButton: CupertinoActionSheetAction(
        onPressed: () => Navigator.pop(ctx),
        child: Text(t.cancel),
      ),
    ),
  );
}
