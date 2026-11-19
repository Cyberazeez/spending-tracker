import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models.dart';
import '../../../core/format.dart';
import '../../../l10n/app_localizations.dart';
import '../../../ui/tokens.dart';
import '../providers.dart';
import '../../../ui/press.dart';
import '../../../ui/chevron.dart';

import 'package:lucide_icons_flutter/lucide_icons.dart';

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

/// Under the search box (owner's pick 2026-11-19: no quick filter chips, the filter button is enough): which
/// period is shown and how many filters are on, as one line that opens the filter sheet, and a gold row to the
/// messages waiting in Needs review while there are any.
class FilterSummary extends ConsumerWidget {
  const FilterSummary({
    super.key,
    required this.onOpenFilter,
    this.reviewCount = 0,
    this.onReview,
  });

  final VoidCallback onOpenFilter;
  final int reviewCount;
  final VoidCallback? onReview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final f = ref.watch(txFilterProvider);
    final muted = AppTokens.muted.resolveFrom(context);
    final period = switch (f.period) {
      TxPeriod.thisMonth => t.filterThisMonth,
      TxPeriod.lastMonth => t.filterLastMonth,
      TxPeriod.all => t.filterAllTime,
      TxPeriod.custom =>
        f.from == null || f.to == null
            ? t.filterCustom
            : '${formatDay(f.from!)} – ${formatDay(f.to!)}',
    };
    final others = f.count - (f.period == TxPeriod.thisMonth ? 0 : 1);
    final line = [period, if (others > 0) t.filterOnCount(others)].join(' · ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          label: '$line, ${t.filterTitle}',
          excludeSemantics: true,
          child: GestureDetector(
            key: const ValueKey('filter-summary'),
            behavior: HitTestBehavior.opaque,
            onTap: onOpenFilter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  line,
                  style: TextStyle(
                    color: muted,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ),
        if (reviewCount > 0 && onReview != null)
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 6),
            child: Semantics(
              button: true,
              label: t.homeToReview(reviewCount),
              excludeSemantics: true,
              child: GestureDetector(
                key: const ValueKey('review-row'),
                behavior: HitTestBehavior.opaque,
                onTap: onReview,
                child: Pressable(
                  offset: const Offset(3, 4),
                  enabled: true,
                  builder: (context, depth) => Container(
                    constraints: const BoxConstraints(minHeight: 48),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: AppTokens.gold.resolveFrom(context),
                      borderRadius: BorderRadius.circular(16),
                      border: outlineOf(context),
                      boxShadow: hardShadowOf(
                        context,
                        offset: const Offset(3, 4) * (1 - depth),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          LucideIcons.messageSquareText,
                          size: 18,
                          color: AppTokens.onTint.resolveFrom(context),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            t.homeToReview(reviewCount),
                            style: TextStyle(
                              color: AppTokens.onTint.resolveFrom(context),
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        ForwardChevron(
                          size: 16,
                          color: AppTokens.onTint.resolveFrom(context),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
