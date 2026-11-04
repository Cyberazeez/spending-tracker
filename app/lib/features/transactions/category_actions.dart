import 'package:flutter/cupertino.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../core/money.dart';
import '../../ui/category_sheet.dart';
import '../../ui/choice_sheet.dart';
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

  // `null` = dismissed, `''` = remove the category. Suggestions: what the same merchant was filed under before.
  final counts = <String, int>{};
  final norm0 = txn.merchantNorm;
  if (norm0 != null && norm0.isNotEmpty) {
    for (final o in ref.read(transactionsProvider).value ?? const <Txn>[]) {
      if (o.id != txn.id && o.merchantNorm == norm0 && o.categoryId != null) {
        counts[o.categoryId!] = (counts[o.categoryId!] ?? 0) + 1;
      }
    }
  }
  final suggestedIds =
      (counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
          .take(3)
          .map((e) => e.key)
          .toList();
  final picked = await showCategorySheet(
    context,
    cats: cats,
    arabic: arabic,
    selectedId: txn.categoryId,
    subtitle: [
      if (txn.merchant != null) txn.merchant!,
      formatSar(txn.amountHalalas, arabic: arabic),
    ].join(' · '),
    suggestedIds: suggestedIds,
    removeLabel: txn.categoryId != null ? t.categoryRemove : null,
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
  final chosen = cats.where((c) => c.id == f.categoryId).firstOrNull;
  final choice = await showChoiceSheet<String>(
    context,
    title: t.filterTitle,
    options: [
      ChoiceOption(
        value: 'all',
        label: t.filterAll,
        icon: LucideIcons.layoutList,
        selected: f.categoryId == null && !f.uncategorizedOnly,
      ),
      ChoiceOption(
        value: 'uncat',
        label: t.filterUncategorized,
        icon: LucideIcons.circleHelp,
        selected: f.uncategorizedOnly,
      ),
      ChoiceOption(
        value: 'cat',
        label: chosen?.label(arabic: arabic) ?? t.categoryPickTitle,
        icon: LucideIcons.tag,
        selected: chosen != null,
      ),
      ChoiceOption(
        value: 'internal',
        label: f.hideInternal ? t.filterShowInternal : t.filterHideInternal,
        icon: LucideIcons.arrowLeftRight,
        selected: f.hideInternal,
      ),
      if (f.isActive)
        ChoiceOption(
          value: 'clear',
          label: t.filterClear,
          icon: LucideIcons.x,
          destructive: true,
        ),
    ],
  );
  if (choice == null) return;
  switch (choice) {
    case 'all':
      ctl.set(f.copyWith(categoryId: null, uncategorizedOnly: false));
    case 'uncat':
      ctl.set(f.copyWith(categoryId: null, uncategorizedOnly: true));
    case 'internal':
      ctl.set(f.copyWith(hideInternal: !f.hideInternal));
    case 'clear':
      ctl.clear();
    case 'cat':
      if (!context.mounted) return;
      final id = await showCategorySheet(
        context,
        cats: cats,
        arabic: arabic,
        selectedId: f.categoryId,
      );
      if (id != null && id.isNotEmpty) {
        ctl.set(f.copyWith(categoryId: id, uncategorizedOnly: false));
      }
  }
}
