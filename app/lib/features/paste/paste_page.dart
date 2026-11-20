import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../core/banks.dart';
import '../../core/format.dart';
import '../../core/models.dart';
import '../../core/money.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../router.dart';
import '../../ui/app_card.dart';
import '../../ui/app_form.dart';
import '../../ui/app_sheet.dart';
import '../../ui/choice_sheet.dart';
import '../../ui/confirm_sheet.dart';
import '../../ui/sheet_frame.dart';
import '../../ui/tokens.dart';
import '../obligations/providers.dart';
import '../transactions/labels.dart';
import '../transactions/providers.dart';

/// The readers a person can pick (the codes of the `paste-sms` function): banks for a purchase, billers for a bill.
const pasteBankReaders = ['alinma', 'alrajhi', 'snb', 'barq', 'd360', 'stc'];
const pasteBillReaders = ['stc900', 'se'];

String pasteReaderName(
  AppLocalizations t,
  String code, {
  required bool arabic,
}) => switch (code) {
  'stc900' => t.pasteReaderStc900,
  'se' => t.pasteReaderSe,
  _ => bankDisplayName(code, arabic: arabic),
};

/// Paste a bank or bill message the Shortcut missed (owner's design 2026-11-20). The message is read on the server
/// by the same readers as the Shortcut's; nothing is saved until Add (or Update / Create bill) is tapped. [bill]
/// only sets the title and which readers are offered first: a purchase pasted here is still read as a purchase.
class PastePage extends ConsumerStatefulWidget {
  const PastePage({super.key, this.bill = false});

  final bool bill;

  @override
  ConsumerState<PastePage> createState() => _PastePageState();
}

class _PastePageState extends ConsumerState<PastePage> {
  final _text = TextEditingController();
  final _billName = TextEditingController();
  String? _reader;
  DateTime? _receivedAt;
  PastePreview? _preview;
  bool _busy = false;
  String? _error;
  int? _dueDay;

  /// The bill was created from this message; a failed save of the message itself retries only that.
  bool _billSaved = false;

  @override
  void dispose() {
    _text.dispose();
    _billName.dispose();
    super.dispose();
  }

  bool get _arabic => ref.read(localeProvider).languageCode == 'ar';

  void _changed() => setState(() {
    _preview = null;
    _error = null;
    _billSaved = false;
    _billName.clear();
    _dueDay = null;
  });

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final s = data?.text?.trim() ?? '';
    if (s.isEmpty || !mounted) return;
    _text.text = s;
    _changed();
  }

  Future<void> _read() async {
    final body = _text.text.trim();
    if (body.isEmpty || _busy) return;
    final t = AppLocalizations.of(context);
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final p = await ref
          .read(dataRepositoryProvider)
          .pastePreview(body, reader: _reader, receivedAt: _receivedAt);
      if (!mounted) return;
      setState(() {
        _preview = p;
        // Defaults only: a name or day the person already chose survives reading again (a new time or bank).
        if (p.kind == 'bill' && p.billId == null) {
          if (_billName.text.trim().isEmpty) {
            _billName.text = p.biller == 'se'
                ? t.pasteReaderSe
                : '${t.pasteBillerStc} ${p.lineLast4 ?? ''}'.trim();
          }
          final issued = toRiyadh(p.issuedAt ?? DateTime.now());
          _dueDay ??= p.biller == 'se' ? issued.day.clamp(1, 28) : 2;
        }
      });
    } catch (_) {
      if (mounted) setState(() => _error = t.pasteFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Saves the message; [ai] when Read with AI was tapped, [force] for Add anyway.
  Future<void> _commit({bool ai = false, bool force = false}) async {
    if (_busy) return;
    final t = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await ref
          .read(dataRepositoryProvider)
          .pasteCommit(
            _text.text.trim(),
            reader: _reader ?? _preview?.reader,
            // The time the message was read with, so a retry or a second paste is the same message.
            receivedAt: _receivedAt ?? _preview?.receivedAt,
            ai: ai,
            force: force,
          );
      if (!mounted) return;
      if (r.outcome == 'same') {
        // The server found a look-alike on save: show it and ask, as on Read.
        final p = _preview;
        setState(() {
          _busy = false;
          if (p != null) {
            _preview = PastePreview(
              kind: p.kind,
              reader: p.reader,
              detected: p.detected,
              type: p.type,
              direction: p.direction,
              bank: p.bank,
              amountHalalas: p.amountHalalas,
              merchant: p.merchant,
              cardLast4: p.cardLast4,
              accountLast4: p.accountLast4,
              occurredAt: p.occurredAt,
              categoryId: p.categoryId,
              receivedAt: p.receivedAt,
              duplicates: r.same,
            );
          }
        });
        return;
      }
      ref
        ..invalidate(transactionsProvider)
        ..invalidate(obligationsProvider);
      final title = r.duplicate
          ? t.pasteAlready
          : switch (r.outcome) {
              'parsed' => t.pasteSaved,
              'review' => t.pasteSavedReview,
              'notice' => t.pasteBillUpdated,
              _ => t.pasteNothing,
            };
      setState(() => _busy = false);
      if (r.outcome == 'unparsed' && !r.duplicate) {
        setState(() => _error = t.pasteUnreadTitle);
        return;
      }
      await showNoticeSheet(context, title: title);
      if (mounted) popOrHome(context);
    } catch (_) {
      if (mounted) setState(() => _error = t.pasteFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// A bill notice with no bill yet: make the bill (with its line, so later notices find it), then save the notice.
  Future<void> _createBill() async {
    final p = _preview;
    final name = _billName.text.trim();
    if (p == null || name.isEmpty || _busy) return;
    final t = AppLocalizations.of(context);
    final issued = toRiyadh(p.issuedAt ?? DateTime.now());
    final day = _dueDay ?? issued.day.clamp(1, 28);
    if (_billSaved) {
      // The bill exists already (the message's own save failed last time): only save the message.
      await _commit();
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(dataRepositoryProvider)
          .saveObligation(
            null,
            ObligationDef(
              name: name.length > 60 ? name.substring(0, 60) : name,
              kind: 'bill',
              amountType: 'estimated',
              amountHalalas: p.amountHalalas ?? p.billExpectedHalalas,
              day: day,
              line: p.lineLast4,
              biller: p.biller,
              // A day on or before the issue day is next month's (issued the 20th, due the 2nd).
              nextMonth: day <= issued.day,
            ),
          );
    } on PostgrestException catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.message.contains('line in use')
              ? t.pasteLineInUse
              : t.pasteFailed;
        });
      }
      return;
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = t.pasteFailed;
        });
      }
      return;
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _billSaved = true;
    });
    await _commit();
  }

  Future<void> _pickReader() async {
    final t = AppLocalizations.of(context);
    final codes = widget.bill
        ? [...pasteBillReaders, ...pasteBankReaders]
        : [...pasteBankReaders, ...pasteBillReaders];
    final picked = await showChoiceSheet<String>(
      context,
      title: t.pasteFrom,
      options: [
        ChoiceOption(
          value: '',
          label: t.pasteFindIt,
          selected: _reader == null,
        ),
        for (final c in codes)
          ChoiceOption(
            value: c,
            label: pasteReaderName(t, c, arabic: _arabic),
            selected: _reader == c,
          ),
      ],
    );
    if (picked == null || !mounted) return;
    setState(() => _reader = picked.isEmpty ? null : picked);
    if (_preview != null) await _read();
  }

  Future<void> _pickTime() async {
    final t = AppLocalizations.of(context);
    var picked = _receivedAt ?? DateTime.now();
    final result = await showAppSheet<DateTime>(
      context: context,
      builder: (ctx) => SheetFrame(
        title: t.pasteWhen,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 216,
                child: CupertinoDatePicker(
                  use24hFormat: true,
                  initialDateTime: picked,
                  maximumDate: DateTime.now().add(const Duration(minutes: 1)),
                  onDateTimeChanged: (d) => picked = d,
                ),
              ),
              const SizedBox(height: 8),
              PrimaryButton(
                label: t.done,
                onPressed: () => Navigator.pop(ctx, picked),
              ),
            ],
          ),
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() => _receivedAt = result);
    if (_preview != null) await _read();
  }

  Future<void> _pickDueDay() async {
    final t = AppLocalizations.of(context);
    final picked = await showChoiceSheet<int>(
      context,
      title: t.pasteDueDay,
      options: [
        for (var d = 1; d <= 28; d++)
          ChoiceOption(
            value: d,
            label: t.pasteDueDayValue(d),
            selected: _dueDay == d,
          ),
      ],
    );
    if (picked != null && mounted) setState(() => _dueDay = picked);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final arabic = ref.watch(localeProvider).languageCode == 'ar';
    final text = AppTokens.text.resolveFrom(context);
    final muted = AppTokens.muted.resolveFrom(context);
    final card = AppTokens.card.resolveFrom(context);
    final p = _preview;

    Widget infoRow({
      required Key key,
      required String label,
      required String value,
      String? chip,
      VoidCallback? onTap,
      bool first = false,
    }) => Semantics(
      button: onTap != null,
      label: '$label, $value',
      excludeSemantics: true,
      child: GestureDetector(
        key: key,
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: first
              ? null
              : BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: AppTokens.bar.resolveFrom(context),
                      width: 1.5,
                    ),
                  ),
                ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: muted,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: TextStyle(
                        color: text,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              if (chip != null) ...[
                const SizedBox(width: 8),
                // Shrinks and wraps with large text instead of pushing the row off the screen.
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppTokens.okBg.resolveFrom(context),
                      borderRadius: BorderRadius.circular(9),
                      border: outlineOf(context),
                    ),
                    child: Text(
                      chip,
                      style: TextStyle(
                        color: AppTokens.onTint.resolveFrom(context),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    final readerCode = _reader ?? p?.reader;
    final when = p?.occurredAt ?? p?.issuedAt ?? _receivedAt;
    final settingsCard = AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          infoRow(
            key: const ValueKey('paste-from'),
            first: true,
            label: t.pasteFrom,
            value: readerCode == null
                ? t.pasteFindIt
                : pasteReaderName(t, readerCode, arabic: arabic),
            chip: _reader == null && p?.detected == true
                ? t.pasteFoundInText
                : null,
            onTap: _busy ? null : _pickReader,
          ),
          infoRow(
            key: const ValueKey('paste-when'),
            label: t.pasteWhen,
            value: when == null ? t.pasteNow : formatDateTime(when),
            onTap: _busy ? null : _pickTime,
          ),
        ],
      ),
    );

    return CupertinoPageScaffold(
      backgroundColor: AppTokens.bg.resolveFrom(context),
      navigationBar: appNavBar(
        context,
        widget.bill ? t.pasteBillTitle : t.pasteTitle,
      ),
      child: SafeArea(
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Text(
              t.pasteIntro,
              style: TextStyle(color: muted, fontSize: 15, height: 1.4),
            ),
            const SizedBox(height: 12),
            CupertinoTextField(
              key: const ValueKey('paste-text'),
              controller: _text,
              placeholder: t.pasteMessage,
              minLines: 5,
              maxLines: 10,
              maxLength: 4000,
              onChanged: (_) => _changed(),
              padding: const EdgeInsets.all(14),
              style: TextStyle(color: text, fontSize: 15, height: 1.45),
              decoration: BoxDecoration(
                color: card,
                borderRadius: BorderRadius.circular(16),
                border: outlineOf(context),
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: SecondaryButton(
                key: const ValueKey('paste-clipboard'),
                label: t.pastePaste,
                icon: LucideIcons.clipboardPaste,
                onPressed: _busy ? null : _paste,
              ),
            ),
            const SizedBox(height: 14),
            settingsCard,
            const SizedBox(height: 14),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _error!,
                  key: const ValueKey('paste-error'),
                  style: TextStyle(
                    color: AppTokens.danger.resolveFrom(context),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            if (p == null)
              PrimaryButton(
                key: const ValueKey('paste-read'),
                label: t.pasteRead,
                busy: _busy,
                onPressed: _text.text.trim().isEmpty ? null : _read,
              )
            else
              ..._result(context, p, arabic),
          ],
        ),
      ),
    );
  }

  List<Widget> _result(BuildContext context, PastePreview p, bool arabic) {
    final t = AppLocalizations.of(context);
    final text = AppTokens.text.resolveFrom(context);
    final muted = AppTokens.muted.resolveFrom(context);
    final ink = AppTokens.onTint.resolveFrom(context);
    Widget note(String s) => Padding(
      padding: const EdgeInsets.fromLTRB(2, 10, 2, 14),
      child: Text(s, style: TextStyle(color: muted, fontSize: 13, height: 1.4)),
    );

    switch (p.kind) {
      case 'transaction':
        final cats = ref.watch(categoriesProvider).value ?? const <Category>[];
        String? catName;
        for (final c in cats) {
          if (c.id == p.categoryId) catName = c.label(arabic: arabic);
        }
        final amount = formatSar(p.amountHalalas ?? 0, arabic: arabic);
        final sign = p.direction == 'in' ? '+' : '−';
        final last4 = p.cardLast4 ?? p.accountLast4;
        return [
          AppCard(
            key: const ValueKey('paste-found'),
            color: AppTokens.accent.resolveFrom(context),
            radius: AppTokens.radiusHero,
            shadow: const Offset(4, 5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  typeLabel(t, p.type ?? 'purchase'),
                  style: TextStyle(
                    color: AppTokens.onAccent.resolveFrom(context),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text(
                    '$sign $amount',
                    style: TextStyle(
                      color: AppTokens.onAccent.resolveFrom(context),
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if ((p.merchant ?? '').isNotEmpty)
                  Text(
                    p.merchant!,
                    style: TextStyle(
                      color: AppTokens.onAccent.resolveFrom(context),
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _kv(t.pasteCategory, catName ?? t.pasteNoCategory, text, muted),
                if (last4 != null)
                  _kv(
                    p.cardLast4 != null ? t.pasteCard : t.pasteAccount,
                    '${bankDisplayName(p.bank ?? '', arabic: arabic)} ·· ${ltrIsolate(last4)}',
                    text,
                    muted,
                  ),
              ],
            ),
          ),
          if (p.duplicates.isNotEmpty) ...[
            const SizedBox(height: 12),
            AppCard(
              key: const ValueKey('paste-duplicate'),
              color: AppTokens.warnBg.resolveFrom(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(LucideIcons.triangleAlert, size: 18, color: ink),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          t.pasteDupTitle,
                          style: TextStyle(
                            color: ink,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  for (final d in p.duplicates)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '${d.merchant ?? ''} · ${formatDateTime(d.occurredAt)} · ${formatSar(d.amountHalalas, arabic: arabic)}',
                        style: TextStyle(
                          color: ink,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            PrimaryButton(
              key: const ValueKey('paste-keep-one'),
              label: t.pasteKeepOne,
              onPressed: _busy ? null : () => popOrHome(context),
            ),
            const SizedBox(height: 10),
            SecondaryButton(
              key: const ValueKey('paste-add-anyway'),
              label: t.pasteAddAnyway,
              busy: _busy,
              onPressed: _busy ? null : () => _commit(force: true),
            ),
          ] else ...[
            note(t.pasteAddHint),
            PrimaryButton(
              key: const ValueKey('paste-add'),
              label: t.pasteAdd,
              busy: _busy,
              onPressed: _commit,
            ),
          ],
        ];
      case 'bill':
        final biller = p.biller == 'se' ? t.pasteBillerSe : t.pasteBillerStc;
        final period =
            p.billPeriodStart ?? toRiyadh(p.issuedAt ?? DateTime.now());
        return [
          AppCard(
            key: const ValueKey('paste-bill'),
            color: AppTokens.gold.resolveFrom(context),
            radius: AppTokens.radiusHero,
            shadow: const Offset(4, 5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.pasteBillFor(biller, ltrIsolate(p.lineLast4 ?? '')),
                  style: TextStyle(
                    color: ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text(
                    formatSar(p.amountHalalas ?? 0, arabic: arabic),
                    style: TextStyle(
                      color: ink,
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (p.billDueDate != null)
                  Text(
                    t.pasteDue(formatDay(p.billDueDate!)),
                    style: TextStyle(
                      color: ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (p.billId != null) ...[
            AppCard(
              key: const ValueKey('paste-bill-match'),
              child: _kv(t.pasteMatched, p.billName ?? '', text, muted),
            ),
            note(t.pasteMatchedHint),
            PrimaryButton(
              key: const ValueKey('paste-update-bill'),
              label: t.pasteUpdateBill(monthName(period, arabic: arabic)),
              busy: _busy,
              onPressed: _commit,
            ),
          ] else ...[
            Text(
              t.pasteNewBillHint(ltrIsolate(p.lineLast4 ?? '')),
              style: TextStyle(color: muted, fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 12),
            AppField(
              key: const ValueKey('paste-bill-name'),
              controller: _billName,
              label: t.pasteBillName,
            ),
            const SizedBox(height: 12),
            AppCard(
              padding: EdgeInsets.zero,
              child: Semantics(
                button: true,
                label: '${t.pasteDueDay}, ${t.pasteDueDayValue(_dueDay ?? 1)}',
                excludeSemantics: true,
                child: GestureDetector(
                  key: const ValueKey('paste-due-day'),
                  behavior: HitTestBehavior.opaque,
                  onTap: _busy ? null : _pickDueDay,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: _kv(
                      t.pasteDueDay,
                      t.pasteDueDayValue(_dueDay ?? 1),
                      text,
                      muted,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            PrimaryButton(
              key: const ValueKey('paste-create-bill'),
              label: t.pasteCreateBill,
              busy: _busy,
              onPressed: _createBill,
            ),
          ],
        ];
      case 'unparsed':
        return [
          AppCard(
            key: const ValueKey('paste-unread'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  p.ambiguous ? t.pasteAmbiguous : t.pasteUnreadTitle,
                  style: TextStyle(
                    color: text,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (!p.ambiguous) ...[
                  const SizedBox(height: 6),
                  Text(
                    t.pasteUnreadBody,
                    style: TextStyle(color: muted, fontSize: 14, height: 1.4),
                  ),
                ],
                const SizedBox(height: 12),
                if (p.aiAvailable && !p.ambiguous) ...[
                  PrimaryButton(
                    key: const ValueKey('paste-ai'),
                    label: t.pasteReadAi,
                    icon: LucideIcons.sparkles,
                    busy: _busy,
                    onPressed: () => _commit(ai: true),
                  ),
                  const SizedBox(height: 10),
                ],
                SecondaryButton(
                  key: const ValueKey('paste-by-hand'),
                  label: t.pasteByHand,
                  onPressed: _busy
                      ? null
                      : () => context.pushReplacement(
                          widget.bill ? obligationFormPath : quickAddPath,
                        ),
                ),
              ],
            ),
          ),
        ];
      default:
        // ignored (a code, an ad) or a card statement (not tracked on Bills): nothing to add.
        return [
          AppCard(
            key: const ValueKey('paste-nothing'),
            child: Text(
              t.pasteNothing,
              style: TextStyle(
                color: text,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ];
    }
  }

  Widget _kv(String k, String v, Color text, Color muted) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        SizedBox(
          width: 110,
          child: Text(
            k,
            style: TextStyle(
              color: muted,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: Text(
            v,
            style: TextStyle(
              color: text,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}
