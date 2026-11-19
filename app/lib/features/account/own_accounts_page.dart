import 'package:flutter/cupertino.dart';

import '../../ui/chevron.dart';
import '../../ui/icon_tile.dart';
import '../../ui/confirm_sheet.dart';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../core/banks.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../router.dart';
import '../../ui/app_card.dart';
import '../../ui/app_form.dart';
import '../../ui/empty_state.dart';
import '../../ui/choice_sheet.dart';
import '../../ui/tokens.dart';
import 'account_providers.dart';
import '../../ui/app_sheet.dart';
import '../../ui/skeleton.dart';

String bankName(BuildContext context, String bank) => bankDisplayName(
  bank,
  arabic: Localizations.localeOf(context).languageCode == 'ar',
);

/// The tile of an account row: sky for bank accounts, gold for credit cards, mint for wallets.
(Color, IconData) kindTile(String kind) => switch (kind) {
  'credit_card' => (const Color(0xFFFFC93C), LucideIcons.creditCard),
  'debit_card' => (const Color(0xFF9CC4FF), LucideIcons.creditCard),
  'wallet' => (const Color(0xFF3FD79B), LucideIcons.wallet),
  _ => (const Color(0xFF9CC4FF), LucideIcons.landmark),
};

String kindName(AppLocalizations t, String kind) => switch (kind) {
  'debit_card' => t.kindDebit,
  'credit_card' => t.kindCredit,
  'wallet' => t.kindWallet,
  _ => t.kindAccount,
};

/// The two boxes of Bank accounts (owner's pick 2026-11-19): bank accounts, and cards (credit, debit / mada and
/// wallets, which the owner wanted with the cards).
enum OwnAccountGroup {
  accounts(['account']),
  cards(['credit_card', 'debit_card', 'wallet']);

  const OwnAccountGroup(this.kinds);
  final List<String> kinds;

  /// Cards hold the card and wallet kinds; Accounts hold everything else, so an unknown kind is never hidden.
  bool holds(OwnAccount a) =>
      this == accounts ? !cards.kinds.contains(a.kind) : kinds.contains(a.kind);
}

/// Account > Bank accounts: the accounts, cards and wallets that are yours, so a move between them is not counted
/// as spending or income. Two boxes, Accounts and Cards, like "Add a bill"; each opens its own list.
class OwnAccountsPage extends ConsumerWidget {
  const OwnAccountsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final list = ref.watch(ownAccountsProvider);
    final text = AppTokens.text.resolveFrom(context);
    final muted = AppTokens.muted.resolveFrom(context);

    Widget box(OwnAccountGroup g, List<OwnAccount> all) {
      final n = all.where(g.holds).length;
      final (title, hint, color, icon) = switch (g) {
        OwnAccountGroup.accounts => (
          t.banksAccounts,
          t.banksAccountsHint,
          const Color(0xFF9CC4FF),
          LucideIcons.landmark,
        ),
        OwnAccountGroup.cards => (
          t.banksCards,
          t.banksCardsHint,
          const Color(0xFFFFC93C),
          LucideIcons.creditCard,
        ),
      };
      return Semantics(
        button: true,
        label: '$title, $hint, ${t.banksCount(n)}',
        excludeSemantics: true,
        child: GestureDetector(
          key: ValueKey('banks-${g.name}'),
          behavior: HitTestBehavior.opaque,
          onTap: () => context.push('$banksPath/${g.name}'),
          child: AppCard(
            pressable: true,
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconTile(color: color, icon: icon, size: 48, iconSize: 22),
                const SizedBox(height: 14),
                Text(
                  title,
                  style: TextStyle(
                    color: text,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  hint,
                  style: TextStyle(
                    color: muted,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  t.banksCount(n),
                  style: TextStyle(
                    color: text,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return CupertinoPageScaffold(
      backgroundColor: AppTokens.bg.resolveFrom(context),
      navigationBar: appNavBar(context, t.accountBanks),
      child: SafeArea(
        child: list.when(
          loading: () => const SkeletonList(heights: [120, 160]),
          error: (_, _) => LoadFailedCard(
            onRetry: () => ref.invalidate(ownAccountsProvider),
          ),
          data: (accounts) => ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 14),
                child: Text(
                  t.accountBanksHint,
                  style: TextStyle(
                    color: muted,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: box(OwnAccountGroup.accounts, accounts)),
                    const SizedBox(width: 10),
                    Expanded(child: box(OwnAccountGroup.cards, accounts)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One box of Bank accounts: its accounts grouped by bank (wallets in a group of their own, last), each opening the
/// edit form, and one button to add another of this type.
class OwnAccountsGroupPage extends ConsumerWidget {
  const OwnAccountsGroupPage({super.key, required this.group});

  final OwnAccountGroup group;

  Future<void> _open(
    BuildContext context,
    WidgetRef ref, [
    OwnAccount? existing,
  ]) async {
    await showAppSheet<void>(
      context: context,
      builder: (_) => _AccountSheet(existing: existing, group: group),
    );
    ref.invalidate(ownAccountsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final list = ref.watch(ownAccountsProvider);
    final muted = AppTokens.muted.resolveFrom(context);
    final text = AppTokens.text.resolveFrom(context);
    final cards = group == OwnAccountGroup.cards;

    Widget row(OwnAccount a) => Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _open(context, ref, a),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                IconTile(
                  color: kindTile(a.kind).$1,
                  icon: kindTile(a.kind).$2,
                  iconSize: 21,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${bankName(context, a.bank)} ${a.last4}',
                        style: TextStyle(
                          color: text,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        [
                          kindName(t, a.kind),
                          if ((a.label ?? '').isNotEmpty) a.label!,
                        ].join(' · '),
                        style: TextStyle(
                          color: muted,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
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
      ),
    );

    Widget section(String title, List<OwnAccount> items) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 6, 4, 8),
          child: Text(
            title,
            style: TextStyle(
              color: muted,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          child: Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0)
                  Container(
                    height: 2,
                    color: AppTokens.bar.resolveFrom(context),
                  ),
                row(items[i]),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
      ],
    );

    return CupertinoPageScaffold(
      backgroundColor: AppTokens.bg.resolveFrom(context),
      navigationBar: appNavBar(context, cards ? t.banksCards : t.banksAccounts),
      child: SafeArea(
        child: list.when(
          loading: () => const SkeletonList(heights: [120, 200]),
          error: (_, _) => LoadFailedCard(
            onRetry: () => ref.invalidate(ownAccountsProvider),
          ),
          data: (all) {
            final mine = all.where(group.holds).toList();
            // Bank by bank in the order they were added; wallets together at the end.
            final byBank = <String, List<OwnAccount>>{};
            final wallets = <OwnAccount>[];
            for (final a in mine) {
              if (a.kind == 'wallet') {
                wallets.add(a);
              } else {
                (byBank[a.bank] ??= []).add(a);
              }
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                if (mine.isEmpty)
                  AppCard(
                    child: Text(
                      cards ? t.banksCardsEmpty : t.banksEmpty,
                      style: TextStyle(color: text, fontSize: 16),
                    ),
                  ),
                for (final e in byBank.entries)
                  section(bankName(context, e.key), e.value),
                if (wallets.isNotEmpty) section(t.banksWallets, wallets),
                const SizedBox(height: 8),
                PrimaryButton(
                  label: cards ? t.bankAddCard : t.bankAdd,
                  onPressed: () => _open(context, ref),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AccountSheet extends ConsumerStatefulWidget {
  const _AccountSheet({this.existing, required this.group});

  final OwnAccount? existing;
  final OwnAccountGroup group;

  @override
  ConsumerState<_AccountSheet> createState() => _AccountSheetState();
}

class _AccountSheetState extends ConsumerState<_AccountSheet> {
  late final _last4 = TextEditingController(text: widget.existing?.last4);
  late final _label = TextEditingController(text: widget.existing?.label);
  late String _bank = widget.existing?.bank ?? _banks.first.code;
  late String _kind = widget.existing?.kind ?? widget.group.kinds.first;

  /// Wallets only make sense as cards: the Accounts box offers banks only.
  List<BankInfo> get _banks => widget.group == OwnAccountGroup.cards
      ? bankList
      : [
          for (final b in bankList)
            if (!b.wallet) b,
        ];

  /// The types this box holds, plus the one an older entry already has.
  List<String> get _kinds => [
    ...widget.group.kinds,
    if (widget.existing != null &&
        !widget.group.kinds.contains(widget.existing!.kind))
      widget.existing!.kind,
  ];
  bool _busy = false;
  String? _error;

  bool get _editing => widget.existing != null;

  @override
  void dispose() {
    _last4.dispose();
    _label.dispose();
    super.dispose();
  }

  Future<void> _pick(
    String title,
    List<String> options,
    String current,
    String Function(String) nameOf,
    ValueChanged<String> set,
  ) async {
    final picked = await showChoiceSheet<String>(
      context,
      title: title,
      options: [
        for (final o in options)
          ChoiceOption(value: o, label: nameOf(o), selected: o == current),
      ],
    );
    if (picked != null) setState(() => set(picked));
  }

  Future<void> _save() async {
    if (_busy) return;
    final t = AppLocalizations.of(context);
    if (!RegExp(r'^[0-9]{4}$').hasMatch(_last4.text.trim())) {
      setState(() => _error = t.bankLast4Invalid);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final repo = ref.read(dataRepositoryProvider);
      if (_editing) {
        await repo.updateOwnAccount(
          id: widget.existing!.id,
          bank: _bank,
          last4: _last4.text.trim(),
          kind: _kind,
          label: _label.text,
        );
      } else {
        await repo.addOwnAccount(
          bank: _bank,
          last4: _last4.text.trim(),
          kind: _kind,
          label: _label.text,
        );
      }
      if (mounted) Navigator.pop(context);
    } on PostgrestException catch (e) {
      if (mounted) {
        setState(
          () => _error = e.code == '23505' ? t.bankDuplicate : t.obSaveFailed,
        );
      }
    } catch (_) {
      if (mounted) setState(() => _error = t.obSaveFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove() async {
    final a = widget.existing!;
    final t = AppLocalizations.of(context);
    final sure = await showConfirmSheet(
      context,
      title: t.bankRemoveConfirm('${bankName(context, a.bank)} ${a.last4}'),
      message: t.bankRemoveNote,
      confirmLabel: t.bankRemove,
      destructive: true,
    );
    if (sure != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(dataRepositoryProvider).deleteOwnAccount(a.id);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = t.obSaveFailed;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final muted = AppTokens.muted.resolveFrom(context);
    final text = AppTokens.text.resolveFrom(context);
    Widget pickRow(String label, String value, VoidCallback onTap) =>
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          // the same outlined field look as AppField and FieldButton
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppTokens.card.resolveFrom(context),
              borderRadius: BorderRadius.circular(14),
              border: outlineOf(context),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 50),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Text(label, style: TextStyle(color: muted, fontSize: 15)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Text(
                          value,
                          textAlign: TextAlign.end,
                          style: TextStyle(
                            color: text,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(LucideIcons.chevronDown, size: 16, color: muted),
                  ],
                ),
              ),
            ),
          ),
        );
    return CupertinoPageScaffold(
      backgroundColor: AppTokens.bg.resolveFrom(context),
      navigationBar: appNavBar(
        context,
        _editing
            ? t.bankEdit
            : widget.group == OwnAccountGroup.cards
            ? t.bankAddCard
            : t.bankAdd,
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            pickRow(
              t.bankPick,
              bankName(context, _bank),
              () => _pick(
                t.bankPick,
                [for (final b in _banks) b.code],
                _bank,
                (c) => bankName(context, c),
                (v) {
                  _bank = v;
                  if (bankInfo(v)?.wallet ?? false) {
                    _kind = 'wallet';
                  } else if (_kind == 'wallet') {
                    _kind = widget.group.kinds.first;
                  }
                },
              ),
            ),
            const SizedBox(height: 12),
            pickRow(
              t.bankKind,
              kindName(t, _kind),
              () => _pick(
                t.bankKind,
                _kinds,
                _kind,
                (k) => kindName(t, k),
                (v) => _kind = v,
              ),
            ),
            const SizedBox(height: 16),
            AppField(
              controller: _last4,
              label: t.bankLast4,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(4),
              ],
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            AppField(
              controller: _label,
              label: t.bankLabelOptional,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _save(),
            ),
            if (_error != null) FormError(_error!),
            const SizedBox(height: 24),
            PrimaryButton(
              label: _editing ? t.bankSaveEdit : t.bankSave,
              busy: _busy,
              onPressed: _save,
            ),
            if (_editing) ...[
              const SizedBox(height: 12),
              SecondaryButton(
                label: t.bankRemove,
                danger: true,
                onPressed: _busy ? null : _remove,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
