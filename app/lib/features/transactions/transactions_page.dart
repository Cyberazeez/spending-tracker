import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/models.dart';
import '../../core/money.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../router.dart';
import '../../ui/empty_state.dart';
import '../../ui/theme.dart';
import 'category_actions.dart';
import 'labels.dart';
import 'providers.dart';

class TransactionsPage extends ConsumerWidget {
  const TransactionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final arabic = ref.watch(localeProvider).languageCode == 'ar';
    final filter = ref.watch(txFilterProvider);
    final txns = ref.watch(transactionsProvider);
    final cats = ref.watch(categoriesProvider).value ?? const <Category>[];
    final review = ref.watch(needsReviewProvider).value ?? const <RawMessage>[];
    final byId = {for (final c in cats) c.id: c};

    return CupertinoPageScaffold(
      child: CustomScrollView(
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: Text(t.txTitle),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () => showFilterSheet(context, ref),
                  child: Icon(
                    filter.categoryId != null ||
                            filter.uncategorizedOnly ||
                            filter.hideInternal
                        ? CupertinoIcons.line_horizontal_3_decrease_circle_fill
                        : CupertinoIcons.line_horizontal_3_decrease_circle,
                  ),
                ),
                CupertinoButton(
                  padding: const EdgeInsetsDirectional.only(start: 12),
                  onPressed: () => context.go(quickAddPath),
                  child: const Icon(CupertinoIcons.add),
                ),
              ],
            ),
          ),
          CupertinoSliverRefreshControl(
            onRefresh: () async {
              ref.invalidate(transactionsProvider);
              ref.invalidate(needsReviewProvider);
              ref.invalidate(categoriesProvider);
              await Future.wait([
                ref
                    .read(transactionsProvider.future)
                    .catchError((_) => <Txn>[]),
                ref
                    .read(needsReviewProvider.future)
                    .catchError((_) => <RawMessage>[]),
              ]);
            },
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: CupertinoSearchTextField(
                placeholder: t.searchHint,
                onChanged: (v) => ref
                    .read(txFilterProvider.notifier)
                    .set(filter.copyWith(query: v.trim())),
              ),
            ),
          ),
          if (review.isNotEmpty && !filter.isActive)
            SliverToBoxAdapter(
              child: CupertinoListSection.insetGrouped(
                children: [
                  CupertinoListTile.notched(
                    leading: const Icon(CupertinoIcons.tray_full),
                    title: Text(t.txOpenReview(review.length)),
                    trailing: const CupertinoListTileChevron(),
                    onTap: () => context.go(reviewPath),
                  ),
                ],
              ),
            ),
          ...txns.when(
            loading: () => [
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CupertinoActivityIndicator()),
              ),
            ],
            error: (_, _) => [
              SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: CupertinoIcons.exclamationmark_triangle,
                  title: t.loadFailed,
                  action: CupertinoButton(
                    onPressed: () => ref.invalidate(transactionsProvider),
                    child: Text(t.tryAgain),
                  ),
                ),
              ),
            ],
            data: (list) => list.isEmpty
                ? [
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: filter.isActive
                          ? EmptyState(
                              icon: CupertinoIcons.search,
                              title: t.noMatches,
                              action: CupertinoButton(
                                onPressed: () =>
                                    ref.read(txFilterProvider.notifier).clear(),
                                child: Text(t.filterClear),
                              ),
                            )
                          : EmptyState(
                              icon: CupertinoIcons.tray,
                              title: t.txEmptyTitle,
                              body: t.txEmptyBody,
                              action: CupertinoButton.filled(
                                onPressed: () => context.go(quickAddPath),
                                child: Text(t.quickAdd),
                              ),
                            ),
                    ),
                  ]
                : [
                    SliverList.builder(
                      itemCount: list.length,
                      itemBuilder: (_, i) => _TxnRow(
                        txn: list[i],
                        arabic: arabic,
                        category: byId[list[i].categoryId],
                        onTap: () => pickCategory(context, ref, list[i], cats),
                      ),
                    ),
                  ],
          ),
        ],
      ),
    );
  }
}

class _TxnRow extends StatelessWidget {
  const _TxnRow({
    required this.txn,
    required this.arabic,
    required this.category,
    required this.onTap,
  });
  final Txn txn;
  final bool arabic;
  final Category? category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);
    final amount = formatSar(txn.amountHalalas, arabic: arabic);
    final sign = txn.isIncoming ? '+' : '−';
    final title = (txn.merchant != null && txn.merchant!.isNotEmpty)
        ? txn.merchant!
        : typeLabel(t, txn.type);
    final categoryText = category?.label(arabic: arabic) ?? t.categoryNone;
    return CupertinoListTile(
      onTap: onTap,
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: categoryText,
              style: TextStyle(
                color: category == null
                    ? CupertinoColors.systemOrange.resolveFrom(context)
                    : AppColors.accent.resolveFrom(context),
                fontWeight: FontWeight.w600,
              ),
            ),
            TextSpan(
              text:
                  ' · ${[if (txn.isInternal) t.txInternal, formatDateTime(txn.occurredAt)].join(' · ')}',
            ),
          ],
        ),
        style: TextStyle(color: secondary),
      ),
      trailing: Directionality(
        textDirection: TextDirection.ltr,
        child: Text(
          '$sign $amount',
          style: TextStyle(
            fontFeatures: const [FontFeature.tabularFigures()],
            fontWeight: FontWeight.w600,
            color: txn.isInternal
                ? secondary
                : txn.isIncoming
                ? CupertinoColors.systemGreen.resolveFrom(context)
                : CupertinoColors.label.resolveFrom(context),
          ),
        ),
      ),
    );
  }
}
