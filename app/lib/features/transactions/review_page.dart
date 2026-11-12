import 'package:flutter/cupertino.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../ui/chevron.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/models.dart';
import '../../core/money.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/app_form.dart';
import '../../ui/empty_state.dart';
import '../../ui/choice_sheet.dart';
import '../../ui/tokens.dart';
import '../../ui/app_card.dart';
import '../../ui/icon_tile.dart';
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
              initialAmount: guessAmountFromSms(m.body),
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

  Future<void> _checkAi(BuildContext context, WidgetRef ref, AiRead a) async {
    final t = AppLocalizations.of(context);
    final arabic = ref.read(localeProvider).languageCode == 'ar';
    final choice = await showChoiceSheet<String>(
      context,
      title: a.txn.merchant ?? a.raw.sender,
      message:
          '${t.aiReadSheetBody}\n\n${formatSar(a.txn.amountHalalas, arabic: arabic)}\n${a.raw.body}',
      options: [
        ChoiceOption(
          value: 'ok',
          label: t.aiReadOk,
          icon: LucideIcons.circleCheck,
        ),
        ChoiceOption(
          value: 'wrong',
          label: t.aiReadWrong,
          icon: LucideIcons.trash2,
          destructive: true,
        ),
      ],
    );
    final repo = ref.read(dataRepositoryProvider);
    try {
      if (choice == 'ok') {
        await repo.confirmAiRead(a.raw.id);
      } else if (choice == 'wrong') {
        await repo.rejectAiRead(a.raw.id, a.txn.id);
      }
    } finally {
      ref.invalidate(aiReadProvider);
      ref.invalidate(needsReviewProvider);
      ref.invalidate(transactionsProvider);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final items = ref.watch(needsReviewProvider);
    final aiRead = ref.watch(aiReadProvider).value ?? const <AiRead>[];
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
          data: (list) => list.isEmpty && aiRead.isEmpty
              ? EmptyState(
                  icon: CupertinoIcons.checkmark_circle,
                  title: t.reviewEmpty,
                  body: t.reviewEmptyBody,
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  children: [
                    if (aiRead.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                        child: Text(
                          t.aiReadHeader,
                          style: TextStyle(
                            color: AppTokens.text.resolveFrom(context),
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      _RowsCard(
                        children: [
                          for (final a in aiRead)
                            Semantics(
                              button: true,
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => _checkAi(context, ref, a),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  child: Row(
                                    children: [
                                      IconTile(
                                        color: AppTokens.gold.resolveFrom(
                                          context,
                                        ),
                                        icon: LucideIcons.sparkles,
                                        iconSize: 21,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              a.txn.merchant ?? a.raw.sender,
                                              style: TextStyle(
                                                color: AppTokens.text
                                                    .resolveFrom(context),
                                                fontSize: 15,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              formatDateTime(a.raw.receivedAt),
                                              style: TextStyle(
                                                color: AppTokens.muted
                                                    .resolveFrom(context),
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        formatSar(
                                          a.txn.amountHalalas,
                                          arabic:
                                              ref
                                                  .watch(localeProvider)
                                                  .languageCode ==
                                              'ar',
                                        ),
                                        style: TextStyle(
                                          color: AppTokens.text.resolveFrom(
                                            context,
                                          ),
                                          fontSize: 15,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
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
                      const SizedBox(height: 16),
                    ],
                    _RowsCard(
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
                                    const IconTile(
                                      color: Color(0xFFDDE3CC),
                                      icon: LucideIcons.messageSquare,
                                      iconSize: 21,
                                    ),
                                    const SizedBox(width: 12),
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
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
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

/// The rows of one section in an outlined card, split by 2 pt lines.
class _RowsCard extends StatelessWidget {
  const _RowsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final line = AppTokens.bar.resolveFrom(context);
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Container(height: 2, color: line),
            children[i],
          ],
        ],
      ),
    );
  }
}
