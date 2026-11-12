import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models.dart';
import '../../../core/providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../../ui/tokens.dart';
import '../providers.dart';

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

/// Quick filters under the search box. They drive the same [txFilterProvider] as the filter sheet.
/// [reviewCount] > 0 adds a chip that opens the inbox of messages that could not be read.
class FilterChips extends ConsumerWidget {
  const FilterChips({
    super.key,
    required this.reviewCount,
    required this.onReview,
  });

  final int reviewCount;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final f = ref.watch(txFilterProvider);
    final ctl = ref.read(txFilterProvider.notifier);
    final arabic = ref.watch(localeProvider).languageCode == 'ar';
    final cats = ref.watch(categoriesProvider).value ?? const [];
    final picked = f.categoryId == null
        ? null
        : cats.where((c) => c.id == f.categoryId).firstOrNull;
    final onlyBase =
        f.categoryId == null &&
        !f.uncategorizedOnly &&
        !f.hideInternal &&
        !f.aiOnly;
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        _Chip(
          label: t.txChipAll,
          selected: onlyBase,
          onTap: () => ctl.set(
            f.copyWith(
              categoryId: null,
              uncategorizedOnly: false,
              hideInternal: false,
              aiOnly: false,
            ),
          ),
        ),
        if (picked != null)
          _Chip(
            label: picked.label(arabic: arabic),
            selected: true,
            onTap: () => ctl.set(f.copyWith(categoryId: null)),
          ),
        // The three quick filters are one choice: picking one clears the others (No category and AI suggested can
        // never match together, and a stack of filters is hard to read). Tapping the chosen one goes back to All.
        _Chip(
          label: t.txChipNoCategory,
          warn: true,
          selected: f.uncategorizedOnly,
          onTap: () => ctl.set(quickFilter(f, QuickFilter.noCategory)),
        ),
        _Chip(
          label: t.txChipAi,
          selected: f.aiOnly,
          onTap: () => ctl.set(quickFilter(f, QuickFilter.ai)),
        ),
        _Chip(
          label: t.txChipHideInternal,
          selected: f.hideInternal,
          onTap: () => ctl.set(quickFilter(f, QuickFilter.hideInternal)),
        ),
        if (reviewCount > 0 && onlyBase)
          _Chip(
            label: t.homeToReview(reviewCount),
            warn: true,
            selected: false,
            onTap: onReview,
          ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
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
          onPressed: onTap,
          child: DecoratedBox(
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
