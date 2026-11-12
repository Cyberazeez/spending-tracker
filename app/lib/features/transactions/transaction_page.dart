import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/banks.dart';
import '../../core/legal.dart';
import '../../core/models.dart';
import '../../core/money.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/app_card.dart';
import '../../ui/app_form.dart';
import '../../ui/app_sheet.dart';
import '../../ui/chevron.dart';
import '../../ui/confirm_sheet.dart';
import '../../ui/icon_tile.dart';
import '../../ui/note_limit.dart';
import '../../ui/sheet_frame.dart';
import '../../ui/tokens.dart';
import '../home/category_groups.dart';
import '../home/group_style.dart';
import '../obligations/providers.dart';
import '../../ui/category_sheet.dart' show categoryIcon;
import 'category_actions.dart';
import 'providers.dart';
import 'txn_delete.dart';

/// One transaction: what, when and how much, its category (and a way to change it), where it came from, the bill it
/// paid, a note, the original bank SMS and Delete.
class TransactionPage extends ConsumerStatefulWidget {
  const TransactionPage({super.key, required this.txn});

  /// As it was when the row was tapped; the page follows the list's newer copy after a change.
  final Txn txn;

  @override
  ConsumerState<TransactionPage> createState() => _TransactionPageState();
}

class _TransactionPageState extends ConsumerState<TransactionPage> {
  late final _note = TextEditingController(text: widget.txn.note ?? '');
  final _noteFocus = FocusNode();
  String _savedNote = '';

  /// The category chosen on this page, until the list catches up (the row can leave a filtered list).
  String? _category;
  bool _categoryChanged = false;

  @override
  void initState() {
    super.initState();
    _savedNote = widget.txn.note ?? '';
    _noteFocus.addListener(() {
      if (!_noteFocus.hasFocus) _saveNote();
    });
  }

  @override
  void dispose() {
    _note.dispose();
    _noteFocus.dispose();
    super.dispose();
  }

  Future<void> _saveNote() async {
    final text = _note.text.trim();
    if (text == _savedNote.trim()) return;
    // Read everything before the save: it can finish after the page is gone (leaving the page saves the note).
    final t = AppLocalizations.of(context);
    final repo = ref.read(dataRepositoryProvider);
    final container = ProviderScope.containerOf(context, listen: false);
    final before = _savedNote;
    _savedNote =
        text; // one save per change, even if the field loses focus twice
    try {
      await repo.setNote(widget.txn.id, text);
      container.invalidate(transactionsProvider);
    } catch (_) {
      _savedNote = before;
      if (mounted) await showNoticeSheet(context, title: t.txnNoteFailed);
    }
  }

  Future<void> _showMessage(String rawId) async {
    final t = AppLocalizations.of(context);
    String? body;
    try {
      body = await ref.read(dataRepositoryProvider).rawMessageBody(rawId);
    } catch (_) {}
    if (!mounted) return;
    await showAppSheet<void>(
      context: context,
      builder: (ctx) => SheetFrame(
        title: t.txnOriginal,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTokens.card.resolveFrom(ctx),
              borderRadius: BorderRadius.circular(14),
              border: outlineOf(ctx, width: AppTokens.outlineThin),
            ),
            child: Directionality(
              textDirection: body == null
                  ? Directionality.of(ctx)
                  : TextDirection.ltr,
              child: Text(
                body ?? t.txnMessageGone,
                style: TextStyle(
                  color: AppTokens.text.resolveFrom(ctx),
                  fontSize: 15,
                  height: 1.4,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final arabic = ref.watch(localeProvider).languageCode == 'ar';
    final list = ref.watch(transactionsProvider).value ?? const <Txn>[];
    var txn =
        list.where((x) => x.id == widget.txn.id).firstOrNull ?? widget.txn;
    // A category changed here shows at once, even when the row has left a filtered list.
    if (_categoryChanged) txn = txn.withCategory(_category);
    final cats = ref.watch(categoriesProvider).value ?? const <Category>[];
    final cat = cats.where((c) => c.id == txn.categoryId).firstOrNull;
    final bill = (ref.watch(obligationsProvider).value ?? const [])
        .where((i) => i.transactionId == txn.id)
        .firstOrNull;
    final text = AppTokens.text.resolveFrom(context);
    final muted = AppTokens.muted.resolveFrom(context);
    final accentText = AppTokens.accentText.resolveFrom(context);
    final local = txn.occurredAt.add(const Duration(hours: 3)); // Riyadh
    final when = DateFormat(
      'EEE d MMM, HH:mm',
      arabic ? 'ar' : 'en',
    ).format(local);
    final amount =
        '${txn.isIncoming ? '+' : '−'}${formatSar(txn.amountHalalas, arabic: arabic, symbol: false)}';
    final tile = cat == null
        ? AppTokens.gold.resolveFrom(context)
        : groupColor(groupOf(cat.name));
    final source = switch (txn.source) {
      'sms' => t.txnSourceSms,
      'ai' => t.txnSourceAi,
      'csv' => t.txnSourceCsv,
      _ => t.txnSourceManual,
    };
    final card = txn.paidWithLast4 == null
        ? '—'
        : '${txn.bank == null ? '' : '${bankDisplayName(txn.bank!, arabic: arabic)} '}•••• ${txn.paidWithLast4}';

    Widget infoRow(String label, String value) => ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Row(
        children: [
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: muted,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: text,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );

    final rows = [
      infoRow(t.txnCard, card),
      infoRow(t.txnSource, source),
      infoRow(t.txnLinkedBill, bill?.name ?? t.txnNone),
    ];

    return CupertinoPageScaffold(
      backgroundColor: AppTokens.bg.resolveFrom(context),
      navigationBar: appNavBar(context, t.txnTitle),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            AppCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconTile(
                        color: tile,
                        icon: cat == null
                            ? LucideIcons.circleHelp
                            : categoryIcon(cat),
                        size: 56,
                        radius: 16,
                        iconSize: 26,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              txn.merchant ?? '—',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: text,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              when,
                              style: TextStyle(
                                color: muted,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: arabic
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Text(
                        amount,
                        key: const ValueKey('txn-amount'),
                        style: TextStyle(
                          color: txn.isIncoming ? accentText : text,
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: tile,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppTokens.line.resolveFrom(context),
                            width: AppTokens.outlineThin,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          child: Text(
                            cat?.label(arabic: arabic) ?? t.txnNoCategory,
                            style: TextStyle(
                              color: AppTokens.onTint.resolveFrom(context),
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(44, 44),
                        onPressed: () async {
                          final saved = await pickCategory(
                            context,
                            ref,
                            txn,
                            cats,
                          );
                          if (saved == null || !mounted) return;
                          setState(() {
                            _categoryChanged = true;
                            _category = saved.isEmpty ? null : saved;
                          });
                        },
                        child: Text(
                          t.txnChangeCategory,
                          style: TextStyle(
                            color: accentText,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
              child: Column(
                children: [
                  for (var i = 0; i < rows.length; i++) ...[
                    if (i > 0)
                      SizedBox(
                        height: 2,
                        child: ColoredBox(
                          color: AppTokens.bar.resolveFrom(context),
                        ),
                      ),
                    rows[i],
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 2, bottom: 6),
              child: Text(
                t.txnNote,
                style: TextStyle(
                  color: text,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            CupertinoTextField(
              key: const ValueKey('txn-note'),
              controller: _note,
              focusNode: _noteFocus,
              placeholder: t.txnAddNote,
              inputFormatters: const [NoteLimit()],
              maxLines: 3,
              minLines: 1,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _noteFocus.unfocus(),
              prefix: Padding(
                padding: const EdgeInsetsDirectional.only(start: 16),
                child: Icon(LucideIcons.pencil, size: 18, color: muted),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
              style: TextStyle(
                color: text,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              placeholderStyle: TextStyle(
                color: muted,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              decoration: BoxDecoration(
                color: AppTokens.card.resolveFrom(context),
                borderRadius: BorderRadius.circular(14),
                border: outlineOf(context),
              ),
            ),
            if (txn.rawMessageId != null) ...[
              const SizedBox(height: 14),
              Semantics(
                button: true,
                label: t.txnOriginal,
                excludeSemantics: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _showMessage(txn.rawMessageId!),
                  child: AppCard(
                    pressable: true,
                    radius: 26,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        Icon(LucideIcons.messageSquare, size: 20, color: text),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            t.txnOriginal,
                            style: TextStyle(
                              color: text,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        ForwardChevron(size: 18, color: muted),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 12,
              children: [
                if (txn.source == 'sms' || txn.source == 'ai')
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(44, 44),
                    onPressed: () => ref
                        .read(urlOpenerProvider)
                        .open(
                          legalUri(
                            LegalPage.support,
                            Localizations.localeOf(context),
                          ),
                        ),
                    child: Text(
                      t.txnReport,
                      style: TextStyle(
                        color: accentText,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                CupertinoButton(
                  key: const ValueKey('txn-delete'),
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(44, 44),
                  onPressed: () async {
                    final gone = await confirmAndDeleteTxn(context, ref, txn);
                    if (gone && context.mounted) Navigator.of(context).pop();
                  },
                  child: Text(
                    t.txDelete,
                    style: TextStyle(
                      color: AppTokens.danger.resolveFrom(context),
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// `/home/txn` opened without a transaction (from a link): a page with a back button instead of a blank screen.
class MissingTransactionPage extends StatelessWidget {
  const MissingTransactionPage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return CupertinoPageScaffold(
      backgroundColor: AppTokens.bg.resolveFrom(context),
      navigationBar: appNavBar(context, t.txnTitle),
      child: SafeArea(
        child: Center(
          child: Text(
            t.noMatches,
            style: TextStyle(color: AppTokens.muted.resolveFrom(context)),
          ),
        ),
      ),
    );
  }
}
