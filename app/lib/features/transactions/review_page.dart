import 'package:flutter/cupertino.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../ui/chevron.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/banks.dart';
import '../../core/format.dart';
import '../../core/models.dart';
import '../../core/money.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/app_card.dart';
import '../../ui/app_form.dart';
import '../../ui/empty_state.dart';
import '../../ui/choice_sheet.dart';
import '../../ui/tokens.dart';
import '../obligations/widgets/bills_widgets.dart';
import '../../ui/icon_tile.dart';
import 'manual_form.dart';
import 'providers.dart';

class ReviewPage extends ConsumerWidget {
  const ReviewPage({super.key});

  /// "Not a purchase": the message leaves the list and nothing is recorded.
  Future<void> _dismiss(WidgetRef ref, RawMessage m) async {
    try {
      await ref.read(dataRepositoryProvider).dismissRaw(m.id);
    } finally {
      ref.invalidate(needsReviewProvider);
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
              showDirection: true,
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
    final arabic = ref.watch(localeProvider).languageCode == 'ar';
    final text = AppTokens.text.resolveFrom(context);
    final muted = AppTokens.muted.resolveFrom(context);

    Widget heading(String s) => Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
      child: Semantics(
        header: true,
        child: Text(
          s,
          style: TextStyle(
            color: text,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );

    return CupertinoPageScaffold(
      backgroundColor: AppTokens.bg.resolveFrom(context),
      navigationBar: appNavBar(context, t.reviewTitle),
      child: SafeArea(
        child: items.when(
          loading: () => const Center(child: CupertinoActivityIndicator()),
          error: (_, _) => Padding(
            padding: const EdgeInsets.all(16),
            child: LoadFailedCard(
              onRetry: () => ref.invalidate(needsReviewProvider),
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
                      heading(t.aiReadHeader),
                      RowsCard(
                        children: [
                          for (final a in aiRead)
                            _AiReadRow(
                              read: a,
                              arabic: arabic,
                              onTap: () => _checkAi(context, ref, a),
                            ),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],
                    if (list.isNotEmpty) ...[
                      heading(t.reviewCouldNotRead),
                      for (final m in list) ...[
                        _MessageCard(
                          message: m,
                          arabic: arabic,
                          onAdd: () => _convert(context, ref, m),
                          onDismiss: () => _dismiss(ref, m),
                        ),
                        const SizedBox(height: 14),
                      ],
                    ],
                    if (list.isEmpty && aiRead.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          t.reviewEmptyBody,
                          style: TextStyle(color: muted, fontSize: 14),
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// A message the AI read: gold sparkle tile, what it found, "SAR 86.00 · 10 Nov", tap to check it.
class _AiReadRow extends StatelessWidget {
  const _AiReadRow({
    required this.read,
    required this.arabic,
    required this.onTap,
  });

  final AiRead read;
  final bool arabic;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final muted = AppTokens.muted.resolveFrom(context);
    final title = read.txn.merchant ?? read.raw.sender;
    final sub =
        '${ltrIsolate(formatSar(read.txn.amountHalalas, arabic: arabic))} · '
        '${formatDateTime(read.raw.receivedAt)}';
    return Semantics(
      button: true,
      label: '$title, $sub',
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              IconTile(
                color: AppTokens.gold.resolveFrom(context),
                icon: LucideIcons.sparkles,
                size: 48,
                iconSize: 22,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppTokens.text.resolveFrom(context),
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      sub,
                      style: TextStyle(
                        color: muted,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ForwardChevron(size: 14, color: muted),
            ],
          ),
        ),
      ),
    );
  }
}

/// A message no reader understood: the bank and time, the SMS in a box, why it is here, Add / Not a purchase.
class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.message,
    required this.arabic,
    required this.onAdd,
    required this.onDismiss,
  });

  final RawMessage message;
  final bool arabic;
  final VoidCallback onAdd;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final text = AppTokens.text.resolveFrom(context);
    final code = bankCodeForSender(message.sender);
    final from = code == null
        ? message.sender
        : bankDisplayName(code, arabic: arabic);
    final tag = switch (message.parseStatus) {
      'low_confidence' => t.reviewTagUnsure,
      'failed' => t.reviewTagFailed,
      _ => t.reviewTagNew,
    };
    Widget link(String label, Color color, VoidCallback onTap, Key key) =>
        CupertinoButton(
          key: key,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          minimumSize: const Size(44, 44),
          onPressed: onTap,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        );
    return AppCard(
      key: ValueKey('review-${message.id}'),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  from,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: text,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  formatDateTime(message.receivedAt),
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    color: AppTokens.muted.resolveFrom(context),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // The SMS as it came, in a box.
          DecoratedBox(
            decoration: BoxDecoration(
              color: AppTokens.bg.resolveFrom(context),
              borderRadius: BorderRadius.circular(16),
              border: outlineOf(context, width: AppTokens.outlineThin),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                message.body,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: text,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  height: 1.35,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            runSpacing: 4,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFA574),
                    borderRadius: BorderRadius.circular(20),
                    border: outlineOf(context, width: AppTokens.outlineThin),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    child: Text(
                      tag,
                      style: TextStyle(
                        color: AppTokens.onTint.resolveFrom(context),
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
              // The two links wrap under each other with large text instead of overflowing.
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  link(
                    t.reviewAdd,
                    AppTokens.accentText.resolveFrom(context),
                    onAdd,
                    ValueKey('review-add-${message.id}'),
                  ),
                  link(
                    t.reviewNotPurchase,
                    AppTokens.muted.resolveFrom(context),
                    onDismiss,
                    ValueKey('review-dismiss-${message.id}'),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
