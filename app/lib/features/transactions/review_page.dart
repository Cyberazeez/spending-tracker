import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../router.dart';
import '../../ui/empty_state.dart';
import 'manual_form.dart';
import 'providers.dart';

class ReviewPage extends ConsumerWidget {
  const ReviewPage({super.key});

  Future<void> _open(BuildContext context, WidgetRef ref, RawMessage m) async {
    final t = AppLocalizations.of(context);
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(t.reviewFrom(m.sender)),
        message: Directionality(
          textDirection: TextDirection.ltr,
          child: Text(m.body, textAlign: TextAlign.start),
        ),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              _convert(context, ref, m);
            },
            child: Text(t.reviewConvert),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(dataRepositoryProvider).dismissRaw(m.id);
              } finally {
                ref.invalidate(needsReviewProvider);
              }
            },
            child: Text(t.reviewDismiss),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: Text(t.cancel),
        ),
      ),
    );
  }

  void _convert(BuildContext context, WidgetRef ref, RawMessage m) {
    final t = AppLocalizations.of(context);
    Navigator.of(context, rootNavigator: true).push(
      CupertinoPageRoute<void>(
        builder: (ctx) => CupertinoPageScaffold(
          navigationBar: CupertinoNavigationBar(middle: Text(t.reviewConvert)),
          child: SafeArea(
            child: ManualTxnForm(
              initialTime: m.receivedAt,
              onSave: (txn) async {
                await ref.read(dataRepositoryProvider).convertRaw(m.id, txn);
                ref.invalidate(needsReviewProvider);
                ref.invalidate(transactionsProvider);
                if (ctx.mounted) Navigator.pop(ctx);
              },
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final items = ref.watch(needsReviewProvider);
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(t.reviewTitle),
        leading: CupertinoNavigationBarBackButton(
          onPressed: () => context.go(homePath),
        ),
      ),
      child: SafeArea(
        child: items.when(
          loading: () => const Center(child: CupertinoActivityIndicator()),
          error: (_, _) => EmptyState(
            icon: CupertinoIcons.exclamationmark_triangle,
            title: t.reviewLoadFailed,
            action: CupertinoButton(
              onPressed: () => ref.invalidate(needsReviewProvider),
              child: Text(t.tryAgain),
            ),
          ),
          data: (list) => list.isEmpty
              ? EmptyState(
                  icon: CupertinoIcons.checkmark_circle,
                  title: t.reviewEmpty,
                  body: t.reviewEmptyBody,
                )
              : ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final m = list[i];
                    return CupertinoListTile(
                      title: Text(m.sender),
                      subtitle: Directionality(
                        textDirection: TextDirection.ltr,
                        child: Text(
                          m.body.replaceAll('\n', ' · '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      additionalInfo: Text(formatDateTime(m.receivedAt)),
                      trailing: const CupertinoListTileChevron(),
                      onTap: () => _open(context, ref, m),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
