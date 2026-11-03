import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../../ui/tokens.dart';
import '../providers.dart';

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
        f.categoryId == null && !f.uncategorizedOnly && !f.hideInternal;
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
            ),
          ),
        ),
        if (picked != null)
          _Chip(
            label: picked.label(arabic: arabic),
            selected: true,
            onTap: () => ctl.set(f.copyWith(categoryId: null)),
          ),
        _Chip(
          label: t.txChipNoCategory,
          dot: const Color(0xFFFFB340),
          selected: f.uncategorizedOnly,
          onTap: () => ctl.set(
            f.copyWith(
              uncategorizedOnly: !f.uncategorizedOnly,
              categoryId: null,
            ),
          ),
        ),
        _Chip(
          label: t.txChipHideInternal,
          selected: f.hideInternal,
          onTap: () => ctl.set(f.copyWith(hideInternal: !f.hideInternal)),
        ),
        if (reviewCount > 0 && onlyBase)
          _Chip(
            label: t.homeToReview(reviewCount),
            dot: const Color(0xFFFFB340),
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
    this.dot,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? dot;

  @override
  Widget build(BuildContext context) {
    final fg = selected
        ? AppTokens.onAccent.resolveFrom(context)
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
              color: selected
                  ? AppTokens.accent.resolveFrom(context)
                  : AppTokens.card.resolveFrom(context),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (dot != null && !selected) ...[
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: dot,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: fg,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
