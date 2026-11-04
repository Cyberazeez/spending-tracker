import 'package:flutter/cupertino.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../ui/chevron.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/app_form.dart';
import '../../ui/empty_state.dart';
import '../../ui/choice_sheet.dart';
import '../../ui/tokens.dart';
import '../obligations/widgets/bills_widgets.dart';
import 'manual_form.dart';
import 'providers.dart';

class ReviewPage extends ConsumerWidget {
  const ReviewPage({super.key});

  Future<void> _open(BuildContext context, WidgetRef ref, RawMessage m) async {
    final t = AppLocalizations.of(context);
    final choice = await showChoiceSheet<String>(
      context,
      title: t.reviewFrom(m.sender),
      message: m.body,
      options: [
        ChoiceOption(
          value: 'convert',
          label: t.reviewConvert,
          icon: LucideIcons.squarePen,
        ),
        ChoiceOption(
          value: 'dismiss',
          label: t.reviewDismiss,
          icon: LucideIcons.trash2,
          destructive: true,
        ),
      ],
    );
    if (choice == 'convert') {
      if (context.mounted) _convert(context, ref, m);
    } else if (choice == 'dismiss') {
      try {
        await ref.read(dataRepositoryProvider).dismissRaw(m.id);
      } finally {
        ref.invalidate(needsReviewProvider);
      }
    }
  }

  void _convert(BuildContext context, WidgetRef ref, RawMessage m) {
    final t = AppLocalizations.of(context);
    Navigator.of(context, rootNavigator: true).push(
      CupertinoPageRoute<void>(
        builder: (ctx) => CupertinoPageScaffold(
          backgroundColor: AppTokens.bg.resolveFrom(ctx),
          navigationBar: CupertinoNavigationBar(
            backgroundColor: AppTokens.bg.resolveFrom(ctx),
            border: null,
            middle: Text(t.reviewConvert),
          ),
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
      backgroundColor: AppTokens.bg.resolveFrom(context),
      navigationBar: appNavBar(context, t.reviewTitle),
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
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  children: [
                    RowsCard(
                      children: [
                        for (final m in list)
                          Semantics(
                            button: true,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => _open(context, ref, m),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            m.sender,
                                            style: TextStyle(
                                              color: AppTokens.text.resolveFrom(
                                                context,
                                              ),
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Directionality(
                                            textDirection: TextDirection.ltr,
                                            child: Text(
                                              m.body.replaceAll('\n', ' · '),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: AppTokens.muted
                                                    .resolveFrom(context),
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            formatDateTime(m.receivedAt),
                                            style: TextStyle(
                                              color: AppTokens.muted
                                                  .resolveFrom(context),
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    ForwardChevron(
                                      size: 14,
                                      color: AppTokens.muted.resolveFrom(
                                        context,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
