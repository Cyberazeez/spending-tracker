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
import 'labels.dart';
import 'providers.dart';

class TransactionsPage extends ConsumerWidget {
  const TransactionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final arabic = ref.watch(localeProvider).languageCode == 'ar';
    final txns = ref.watch(transactionsProvider);
    final review = ref.watch(needsReviewProvider).value ?? const <RawMessage>[];

    return CupertinoPageScaffold(
      child: CustomScrollView(
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: Text(t.txTitle),
            trailing: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => context.go(quickAddPath),
              child: const Icon(CupertinoIcons.add),
            ),
          ),
          CupertinoSliverRefreshControl(
            onRefresh: () async {
              ref.invalidate(transactionsProvider);
              ref.invalidate(needsReviewProvider);
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
          if (review.isNotEmpty)
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
                      child: EmptyState(
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
                      itemBuilder: (_, i) =>
                          _TxnRow(txn: list[i], arabic: arabic),
                    ),
                  ],
          ),
        ],
      ),
    );
  }
}

class _TxnRow extends StatelessWidget {
  const _TxnRow({required this.txn, required this.arabic});
  final Txn txn;
  final bool arabic;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);
    final amount = formatSar(txn.amountHalalas, arabic: arabic);
    final sign = txn.isIncoming ? '+' : '−';
    final title = (txn.merchant != null && txn.merchant!.isNotEmpty)
        ? txn.merchant!
        : typeLabel(t, txn.type);
    return CupertinoListTile(
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        [
          typeLabel(t, txn.type),
          if (txn.isInternal) t.txInternal,
          formatDateTime(txn.occurredAt),
        ].join(' · '),
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
