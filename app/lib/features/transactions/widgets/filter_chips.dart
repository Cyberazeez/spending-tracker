import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models.dart';
import '../../../core/format.dart';
import '../../../l10n/app_localizations.dart';
import '../../../ui/tokens.dart';
import '../providers.dart';
import '../../../ui/press.dart';

enum QuickFilter { noCategory, ai, hideInternal }

/// The filter after tapping a quick chip: that chip on and the other two off, or all three off when it was already
/// on. Picking "No category" also drops a chosen category (they contradict each other).
TxFilter quickFilter(TxFilter f, QuickFilter chip) {
  final wasOn = switch (chip) {
    QuickFilter.noCategory => f.uncategorizedOnly,
    QuickFilter.ai => f.aiOnly,
    QuickFilter.hideInternal => f.hideInternal,
  };
  return f.copyWith(
    uncategorizedOnly: !wasOn && chip == QuickFilter.noCategory,
    aiOnly: !wasOn && chip == QuickFilter.ai,
    hideInternal: !wasOn && chip == QuickFilter.hideInternal,
    categoryId: !wasOn && chip == QuickFilter.noCategory ? null : f.categoryId,
  );
}

/// The chips under the search box: the period and the account (tap: the filter sheet), "No category · N" (a quick
/// switch) and, when some rows were categorised by the AI, "AI suggested". They drive the same [txFilterProvider]
/// as the filter sheet.
class FilterChips extends ConsumerWidget {
  const FilterChips({
    super.key,
    required this.onOpenFilter,
    this.showAi = false,
    this.reviewCount = 0,
    this.onReview,
  });

  final VoidCallback onOpenFilter;

  /// Messages waiting in Needs review: a gold "N to review" chip that opens it (only while something waits).
  final int reviewCount;
  final VoidCallback? onReview;

  /// Offer the "AI suggested" chip (some rows were categorised by the AI, or the chip is on).
  final bool showAi;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final f = ref.watch(txFilterProvider);
    final ctl = ref.read(txFilterProvider.notifier);
    final uncategorized = ref.watch(uncategorizedCountProvider).value ?? 0;
    final period = switch (f.period) {
      TxPeriod.thisMonth => t.filterThisMonth,
      TxPeriod.lastMonth => t.filterLastMonth,
      TxPeriod.all => t.filterAllTime,
      TxPeriod.custom =>
        f.from == null || f.to == null
            ? t.filterCustom
            : '${formatDay(f.from!)} – ${formatDay(f.to!)}',
    };
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        _Chip(
          key: const ValueKey('chip-period'),
          label: period,
          selected: true,
          onTap: onOpenFilter,
        ),
        _Chip(
          key: const ValueKey('chip-account'),
          label: f.accountLast4 == null
              ? t.txChipAllBanks
              : '•••• ${f.accountLast4}',
          selected: f.accountLast4 != null,
          onTap: onOpenFilter,
        ),
        _Chip(
          label: uncategorized > 0
              ? t.txChipNoCategoryCount(uncategorized)
              : t.txChipNoCategory,
          warn: true,
          selected: f.uncategorizedOnly,
          onTap: () => ctl.set(quickFilter(f, QuickFilter.noCategory)),
        ),
        if (showAi || f.aiOnly)
          _Chip(
            label: t.txChipAi,
            selected: f.aiOnly,
            onTap: () => ctl.set(quickFilter(f, QuickFilter.ai)),
          ),
        if (reviewCount > 0 && onReview != null)
          _Chip(
            label: t.homeToReview(reviewCount),
            warn: true,
            selected: false,
            onTap: onReview!,
          ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.warn = false,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// Something waits for the owner (uncategorised rows, messages to review): gold until it is selected.
  final bool warn;

  @override
  Widget build(BuildContext context) {
    final fill = selected
        ? AppTokens.accent.resolveFrom(context)
        : warn
        ? AppTokens.gold.resolveFrom(context)
        : AppTokens.card.resolveFrom(context);
    final fg = selected
        ? AppTokens.onAccent.resolveFrom(context)
        : warn
        ? AppTokens.onTint.resolveFrom(context)
        : AppTokens.text.resolveFrom(context);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      onTap: onTap,
      child: ExcludeSemantics(
        child: CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: const Size(44, 44),
          pressedOpacity: 1,
          onPressed: onTap,
          child: PressShadow(
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(20),
              border: outlineOf(context, width: AppTokens.outlineThin),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Text(
                label,
                style: TextStyle(
                  color: fg,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
