import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/banks.dart';
import '../../core/models.dart';
import '../../core/money.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/app_card.dart';
import '../../ui/app_form.dart';
import '../../ui/app_sheet.dart';
import '../../ui/category_sheet.dart';
import '../../ui/chevron.dart';
import '../../ui/choice_sheet.dart';
import '../../ui/icon_tile.dart';
import '../../ui/sheet_frame.dart';
import '../../ui/tokens.dart';
import '../account/account_providers.dart';
import '../account/own_accounts_page.dart' show kindTile;
import '../home/category_groups.dart';
import '../home/group_style.dart';
import '../obligations/widgets/bills_widgets.dart';
import 'providers.dart';

/// Add a transaction by hand: the amount in a big card, the merchant, the category, the date and time, the account
/// it was paid with and a note. Used by Quick add and by "Add as transaction" in the review inbox, where
/// [showDirection] adds Spent / Received (a bank SMS can be money coming in).
class ManualTxnForm extends ConsumerStatefulWidget {
  const ManualTxnForm({
    super.key,
    required this.onSave,
    this.initialTime,
    this.initialMerchant,
    this.initialAmount,
    this.showDirection = false,
  });

  final Future<void> Function(ManualTxn txn) onSave;
  final DateTime? initialTime;
  final String? initialMerchant;

  /// Amount text to start with (a guess read from an unparsed SMS); the person can change it.
  final String? initialAmount;
  final bool showDirection;

  @override
  ConsumerState<ManualTxnForm> createState() => _ManualTxnFormState();
}

class _ManualTxnFormState extends ConsumerState<ManualTxnForm> {
  late final TextEditingController _amount = TextEditingController(
    text: widget.initialAmount,
  );
  late final TextEditingController _merchant = TextEditingController(
    text: widget.initialMerchant,
  );
  final _note = TextEditingController();
  late DateTime _when = (widget.initialTime ?? DateTime.now()).toLocal();
  String _direction = 'out';
  String? _categoryId;
  OwnAccount? _account;
  bool _busy = false;
  bool _invalid = false;
  bool _failed = false;

  @override
  void dispose() {
    _amount.dispose();
    _merchant.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final h = parseHalalas(_amount.text);
    setState(() {
      _invalid = h == null;
      _failed = false;
    });
    if (h == null) return;
    setState(() => _busy = true);
    try {
      final m = _merchant.text.trim();
      await widget.onSave(
        ManualTxn(
          direction: _direction,
          amountHalalas: h,
          occurredAt: _when.toUtc(),
          merchant: m.isEmpty ? null : m,
          categoryId: _categoryId,
          bank: _account?.bank,
          accountLast4: _account?.last4,
          note: _note.text.trim().isEmpty ? null : _note.text.trim(),
        ),
      );
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// The date or the time ([mode]) in a picker sheet; the other part stays.
  Future<void> _pick(CupertinoDatePickerMode mode) async {
    final t = AppLocalizations.of(context);
    var picked = _when;
    final result = await showAppSheet<DateTime>(
      context: context,
      builder: (ctx) => SheetFrame(
        title: mode == CupertinoDatePickerMode.time ? t.qaTime : t.qaDate,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 216,
                child: CupertinoDatePicker(
                  mode: mode,
                  use24hFormat: true,
                  initialDateTime: _when,
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
    if (result != null && mounted) setState(() => _when = result);
  }

  Future<void> _pickCategory(List<Category> cats, bool arabic) async {
    final id = await showCategorySheet(
      context,
      cats: cats,
      arabic: arabic,
      selectedId: _categoryId,
      removeLabel: _categoryId == null
          ? null
          : AppLocalizations.of(context).categoryRemove,
    );
    if (id == null || !mounted) return;
    setState(() => _categoryId = id.isEmpty ? null : id);
  }

  Future<void> _pickAccount(List<OwnAccount> accounts, bool arabic) async {
    final t = AppLocalizations.of(context);
    final choice = await showChoiceSheet<String>(
      context,
      title: t.qaPaidWith,
      options: [
        ChoiceOption(value: '', label: t.qaNotSet, selected: _account == null),
        for (final a in accounts)
          ChoiceOption(
            value: a.id,
            label: _accountLabel(a, arabic),
            icon: kindTile(a.kind).$2,
            selected: _account?.id == a.id,
          ),
      ],
    );
    if (choice == null || !mounted) return;
    setState(
      () => _account = accounts.where((a) => a.id == choice).firstOrNull,
    );
  }

  String _accountLabel(OwnAccount a, bool arabic) =>
      '${bankDisplayName(a.bank, arabic: arabic)} •••• ${a.last4}';

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final arabic = ref.watch(localeProvider).languageCode == 'ar';
    final cats = ref.watch(categoriesProvider).value ?? const <Category>[];
    final accounts = ref.watch(ownAccountsProvider).value ?? const [];
    final cat = cats.where((c) => c.id == _categoryId).firstOrNull;
    final text = AppTokens.text.resolveFrom(context);
    final muted = AppTokens.muted.resolveFrom(context);

    Widget label(String s) => Padding(
      padding: const EdgeInsetsDirectional.only(start: 2, top: 14, bottom: 6),
      child: Text(
        s,
        style: TextStyle(
          color: text,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );

    // A pressable row card: a tile, a small label over the value, a chevron (category, paid with).
    Widget pickRow({
      required Key key,
      required Color tile,
      required IconData icon,
      required String caption,
      required String value,
      required bool chosen,
      required VoidCallback onTap,
    }) => Semantics(
      button: true,
      label: '$caption, $value',
      excludeSemantics: true,
      child: GestureDetector(
        key: key,
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AppCard(
          pressable: true,
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              IconTile(color: tile, icon: icon, size: 46, iconSize: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      caption,
                      style: TextStyle(
                        color: muted,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: chosen ? text : muted,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              ForwardChevron(size: 18, color: muted),
            ],
          ),
        ),
      ),
    );

    final loc = arabic ? 'ar' : 'en';
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        if (widget.showDirection) ...[
          PillSegments<String>(
            value: _direction,
            labels: {'out': t.qaSpent, 'in': t.qaReceived},
            onChanged: (v) => setState(() => _direction = v),
          ),
          const SizedBox(height: 12),
        ],
        // The amount, big, in its own card.
        AppCard(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t.qaAmountLabel,
                style: TextStyle(
                  color: muted,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Directionality(
                textDirection: TextDirection.ltr,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      arabic ? 'ر.س' : 'SAR',
                      style: TextStyle(
                        color: muted,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Semantics(
                        label: t.qaAmount,
                        textField: true,
                        child: CupertinoTextField(
                          key: const ValueKey('qa-amount'),
                          controller: _amount,
                          placeholder: '0.00',
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          decoration: null,
                          style: TextStyle(
                            color: text,
                            fontSize: 44,
                            fontWeight: FontWeight.w800,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                          placeholderStyle: TextStyle(
                            color: muted.withValues(alpha: 0.5),
                            fontSize: 44,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (_invalid) FormError(t.qaAmountInvalid),
        label(t.qaMerchantLabel),
        AppField(controller: _merchant, placeholder: t.qaMerchantHint),
        const SizedBox(height: 14),
        pickRow(
          key: const ValueKey('qa-category'),
          tile: cat == null
              ? AppTokens.bar.resolveFrom(context)
              : groupColor(groupOf(cat.name)),
          icon: cat == null ? LucideIcons.tag : categoryIcon(cat),
          caption: t.qaCategory,
          value: cat?.label(arabic: arabic) ?? t.qaChoose,
          chosen: cat != null,
          onTap: () => _pickCategory(cats, arabic),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  label(t.qaDate),
                  FieldButton(
                    key: const ValueKey('qa-date'),
                    icon: LucideIcons.calendar,
                    label: DateFormat('EEE d MMM', loc).format(_when),
                    onPressed: () => _pick(CupertinoDatePickerMode.date),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  label(t.qaTime),
                  FieldButton(
                    key: const ValueKey('qa-time'),
                    label: DateFormat('HH:mm', 'en').format(_when),
                    onPressed: () => _pick(CupertinoDatePickerMode.time),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        pickRow(
          key: const ValueKey('qa-account'),
          tile: _account == null
              ? AppTokens.bar.resolveFrom(context)
              : kindTile(_account!.kind).$1,
          icon: _account == null
              ? LucideIcons.creditCard
              : kindTile(_account!.kind).$2,
          caption: t.qaPaidWith,
          value: _account == null
              ? t.qaNotSet
              : _accountLabel(_account!, arabic),
          chosen: _account != null,
          onTap: () => _pickAccount(accounts, arabic),
        ),
        label(t.qaNote),
        AppField(controller: _note, placeholder: t.qaOptional),
        if (_failed) FormError(t.qaSaveFailed),
        const SizedBox(height: 20),
        PrimaryButton(label: t.qaSave, busy: _busy, onPressed: _save),
      ],
    );
  }
}
