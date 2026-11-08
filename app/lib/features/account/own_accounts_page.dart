import 'package:flutter/cupertino.dart';

import '../../ui/confirm_sheet.dart';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../core/banks.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/app_card.dart';
import '../../ui/app_form.dart';
import '../../ui/empty_state.dart';
import '../../ui/choice_sheet.dart';
import '../../ui/tokens.dart';
import 'account_providers.dart';

String bankName(BuildContext context, String bank) => bankDisplayName(
  bank,
  arabic: Localizations.localeOf(context).languageCode == 'ar',
);

String kindName(AppLocalizations t, String kind) => switch (kind) {
  'debit_card' => t.kindDebit,
  'credit_card' => t.kindCredit,
  'wallet' => t.kindWallet,
  _ => t.kindAccount,
};

/// Account > Bank accounts: the accounts, cards and wallets that are yours, so a move between them is not counted
/// as spending or income.
class OwnAccountsPage extends ConsumerWidget {
  const OwnAccountsPage({super.key});

  /// Opens the form to add an account, or to edit [existing].
  Future<void> _open(
    BuildContext context,
    WidgetRef ref, [
    OwnAccount? existing,
  ]) async {
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (_) => _AccountSheet(existing: existing),
    );
    ref.invalidate(ownAccountsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final list = ref.watch(ownAccountsProvider);
    final muted = AppTokens.muted.resolveFrom(context);
    return CupertinoPageScaffold(
      backgroundColor: AppTokens.bg.resolveFrom(context),
      navigationBar: appNavBar(context, t.accountBanks),
      child: SafeArea(
        child: list.when(
          loading: () => const Center(child: CupertinoActivityIndicator()),
          error: (_, _) => EmptyState(
            icon: CupertinoIcons.exclamationmark_triangle,
            title: t.loadFailed,
            action: CupertinoButton(
              onPressed: () => ref.invalidate(ownAccountsProvider),
              child: Text(t.tryAgain),
            ),
          ),
          data: (accounts) => ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
                child: Text(
                  t.accountBanksHint,
                  style: TextStyle(color: muted, fontSize: 14),
                ),
              ),
              if (accounts.isEmpty)
                AppCard(
                  child: Text(
                    t.banksEmpty,
                    style: TextStyle(
                      color: AppTokens.text.resolveFrom(context),
                      fontSize: 16,
                    ),
                  ),
                )
              else
                AppCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: Column(
                    children: [
                      for (var i = 0; i < accounts.length; i++) ...[
                        if (i > 0)
                          Container(
                            height: 1,
                            color: AppTokens.bar.resolveFrom(context),
                          ),
                        Semantics(
                          button: true,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => _open(context, ref, accounts[i]),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(minHeight: 56),
                              child: Row(
                                children: [
                                  Icon(
                                    LucideIcons.landmark,
                                    size: 20,
                                    color: AppTokens.accent.resolveFrom(
                                      context,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${bankName(context, accounts[i].bank)} ${accounts[i].last4}',
                                          style: TextStyle(
                                            color: AppTokens.text.resolveFrom(
                                              context,
                                            ),
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Text(
                                          [
                                            kindName(t, accounts[i].kind),
                                            if ((accounts[i].label ?? '')
                                                .isNotEmpty)
                                              accounts[i].label!,
                                          ].join(' · '),
                                          style: TextStyle(
                                            color: muted,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              const SizedBox(height: 20),
              PrimaryButton(
                label: t.bankAdd,
                onPressed: () => _open(context, ref),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountSheet extends ConsumerStatefulWidget {
  const _AccountSheet({this.existing});

  final OwnAccount? existing;

  @override
  ConsumerState<_AccountSheet> createState() => _AccountSheetState();
}

class _AccountSheetState extends ConsumerState<_AccountSheet> {
  late final _last4 = TextEditingController(text: widget.existing?.last4);
  late final _label = TextEditingController(text: widget.existing?.label);
  late String _bank = widget.existing?.bank ?? bankList.first.code;
  late String _kind = widget.existing?.kind ?? OwnAccount.kinds.first;
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
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppTokens.card.resolveFrom(context),
              borderRadius: BorderRadius.circular(16),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 52),
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
                    Icon(CupertinoIcons.chevron_down, size: 14, color: muted),
                  ],
                ),
              ),
            ),
          ),
        );
    return CupertinoPageScaffold(
      backgroundColor: AppTokens.bg.resolveFrom(context),
      navigationBar: CupertinoNavigationBar(
        backgroundColor: AppTokens.bg.resolveFrom(context),
        border: null,
        middle: Text(_editing ? t.bankEdit : t.bankAdd),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.pop(context),
          child: Text(t.cancel),
        ),
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
                [for (final b in bankList) b.code],
                _bank,
                (c) => bankName(context, c),
                (v) {
                  _bank = v;
                  if (bankInfo(v)?.wallet ?? false) _kind = 'wallet';
                },
              ),
            ),
            const SizedBox(height: 12),
            pickRow(
              t.bankKind,
              kindName(t, _kind),
              () => _pick(
                t.bankKind,
                OwnAccount.kinds,
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
              CupertinoButton(
                onPressed: _busy ? null : _remove,
                child: Text(
                  t.bankRemove,
                  style: const TextStyle(color: CupertinoColors.destructiveRed),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
