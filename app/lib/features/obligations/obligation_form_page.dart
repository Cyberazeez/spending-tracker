import 'package:flutter/cupertino.dart';

import '../../ui/settings_group.dart' show appSwitch;
import '../../ui/chevron.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../core/format.dart';
import '../../core/lock.dart';
import '../../core/models.dart';
import '../../core/money.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/category_sheet.dart';
import '../../ui/choice_sheet.dart';
import '../../router.dart';
import '../../ui/app_card.dart';
import '../../ui/app_form.dart';
import '../../ui/tokens.dart';
import '../insights/metrics.dart';
import '../transactions/providers.dart';
import 'logic.dart' show riyadhToday;
import 'providers.dart';
import 'widgets/bills_widgets.dart';
import '../../ui/press.dart';

/// Create ([obligationId] null) or edit one bill, fixed payment or loan by hand.
class ObligationFormPage extends ConsumerStatefulWidget {
  const ObligationFormPage({super.key, this.obligationId});

  final String? obligationId;

  @override
  ConsumerState<ObligationFormPage> createState() => _ObligationFormPageState();
}

class _ObligationFormPageState extends ConsumerState<ObligationFormPage> {
  final _name = TextEditingController();
  final _amount = TextEditingController();
  final _words = TextEditingController();
  String _kind = 'fixed';
  String _amountType = 'fixed';
  String _frequency = 'monthly';
  int _day = 1;
  int _startMonth = 1;
  int _grace = 3;
  int _lead = 2;
  int _tolerance = 10;
  bool _auto = false;
  String? _categoryId;
  bool _loading = false;
  bool _loadFailed = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final today = riyadhToday(ref.read(clockProvider)());
    _startMonth = today.month;
    _day = today.day;
    if (widget.obligationId != null) {
      _loading = true;
      _load();
    }
  }

  Future<void> _load() async {
    try {
      final d = await ref
          .read(dataRepositoryProvider)
          .obligation(widget.obligationId!);
      if (!mounted) return;
      setState(() {
        _name.text = d.name;
        _kind = d.kind;
        _amountType = d.amountType;
        _amount.text = d.amountHalalas == null
            ? ''
            : (d.amountHalalas! / 100).toStringAsFixed(2);
        _frequency = d.frequency;
        _day = d.day;
        _startMonth = d.startMonth ?? _startMonth;
        _grace = d.graceDays;
        _lead = d.leadDays;
        _categoryId = d.categoryId;
        _words.text = d.merchantWords.join(', ');
        _tolerance = d.tolerancePct;
        _auto = d.autoMerchant;
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadFailed = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _words.dispose();
    super.dispose();
  }

  List<String>? _parseWords() {
    final words = _words.text
        .split(RegExp(r'[,،]'))
        .map((w) => w.trim())
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.length > 5 || words.any((w) => w.length > 30)) return null;
    return words;
  }

  Future<void> _save() async {
    final t = AppLocalizations.of(context);
    final name = _name.text.trim();
    if (name.isEmpty || name.length > 60) {
      setState(() => _error = t.obfNameRequired);
      return;
    }
    int? amount;
    if (_amount.text.trim().isNotEmpty || _kind != 'bill') {
      amount = parseHalalas(_amount.text);
      if (amount == null || amount <= 0 || amount > maxBudgetHalalas) {
        setState(() => _error = t.obAmountInvalid);
        return;
      }
    }
    final words = _parseWords();
    if (words == null) {
      setState(() => _error = t.obfWordsInvalid);
      return;
    }
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      await ref
          .read(dataRepositoryProvider)
          .saveObligation(
            widget.obligationId,
            ObligationDef(
              name: name,
              kind: _kind,
              amountType: _amountType,
              amountHalalas: amount,
              frequency: _frequency,
              day: _day,
              startMonth: _frequency == 'monthly' ? null : _startMonth,
              graceDays: _grace,
              leadDays: _lead,
              categoryId: _categoryId,
              merchantWords: words,
              tolerancePct: _tolerance,
              autoMerchant: _auto,
            ),
          );
      ref.invalidate(obligationsProvider);
      if (mounted) popOrHome(context);
    } on PostgrestException catch (e) {
      if (mounted) {
        setState(
          () => _error = e.code == '23505' ? t.obfNameTaken : t.obSaveFailed,
        );
      }
    } catch (_) {
      if (mounted) setState(() => _error = t.obSaveFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickMonth(bool arabic) async {
    final t = AppLocalizations.of(context);
    final picked = await showChoiceSheet<int>(
      context,
      title: t.obfStartMonth,
      options: [
        for (var m = 1; m <= 12; m++)
          ChoiceOption(
            value: m,
            label: monthName(DateTime.utc(2026, m), arabic: arabic),
            selected: m == _startMonth,
          ),
      ],
    );
    if (picked != null) setState(() => _startMonth = picked);
  }

  Future<void> _pickCategory(List<Category> cats, bool arabic) async {
    final t = AppLocalizations.of(context);
    final picked = await showCategorySheet(
      context,
      cats: cats,
      arabic: arabic,
      selectedId: _categoryId,
      removeLabel: t.obfNoCategory,
      removeIsDestructive: false,
    );
    if (picked != null) {
      setState(() => _categoryId = picked.isEmpty ? null : picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final arabic = ref.watch(localeProvider).languageCode == 'ar';
    final cats = ref.watch(categoriesProvider).value ?? const <Category>[];
    final muted = AppTokens.muted.resolveFrom(context);
    final text = AppTokens.text.resolveFrom(context);
    final cat = cats.where((c) => c.id == _categoryId).firstOrNull;

    Widget label(String s) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        s,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: text,
        ),
      ),
    );
    Widget note(String s) => Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(s, style: TextStyle(fontSize: 12, color: muted)),
    );
    Widget field(
      TextEditingController c, {
      TextInputType? type,
      String? hint,
    }) => CupertinoTextField(
      controller: c,
      keyboardType: type,
      placeholder: hint,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      style: TextStyle(color: text, fontSize: 16, fontWeight: FontWeight.w500),
      placeholderStyle: TextStyle(color: muted, fontSize: 16),
      decoration: BoxDecoration(
        color: AppTokens.bg.resolveFrom(context),
        borderRadius: BorderRadius.circular(14),
        border: outlineOf(context, width: AppTokens.outlineThin),
      ),
    );
    Widget gap() => const SizedBox(height: 16);
    Widget card(List<Widget> children) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );

    return CupertinoPageScaffold(
      backgroundColor: AppTokens.bg.resolveFrom(context),
      navigationBar: appNavBar(
        context,
        widget.obligationId == null ? t.obNew : t.obEditTitle,
      ),
      child: SafeArea(
        child: _loading
            ? const Center(child: CupertinoActivityIndicator())
            : _loadFailed
            ? Center(child: Text(t.loadFailed))
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                children: [
                  card([
                    label(t.obfName),
                    field(_name),
                    gap(),
                    label(t.obfType),
                    PillSegments<String>(
                      value: _kind,
                      onChanged: (v) => setState(() => _kind = v),
                      labels: {
                        'bill': t.obfKindBill,
                        'fixed': t.obfKindFixed,
                        'loan': t.obfKindLoan,
                      },
                    ),
                  ]),
                  card([
                    PillSegments<String>(
                      value: _amountType,
                      onChanged: (v) => setState(() => _amountType = v),
                      labels: {
                        'fixed': t.obfAmountFixed,
                        'estimated': t.obfAmountEstimated,
                      },
                    ),
                    gap(),
                    label(t.obfAmount),
                    field(
                      _amount,
                      type: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                    if (_kind == 'bill') note(t.obfAmountBillNote),
                  ]),
                  card([
                    label(t.obfRepeats),
                    PillSegments<String>(
                      value: _frequency,
                      onChanged: (v) => setState(() => _frequency = v),
                      labels: {
                        'monthly': t.obfMonthly,
                        'quarterly': t.obfQuarterly,
                        'annual': t.obfAnnual,
                      },
                    ),
                    gap(),
                    _Stepper(
                      title: t.obfDueDay,
                      value: _day,
                      min: 1,
                      max: 31,
                      onChanged: (v) => setState(() => _day = v),
                    ),
                    note(t.obfDueDayNote),
                    if (_frequency != 'monthly') ...[
                      gap(),
                      _TapRow(
                        title: t.obfStartMonth,
                        value: monthName(
                          DateTime.utc(2026, _startMonth),
                          arabic: arabic,
                        ),
                        onTap: () => _pickMonth(arabic),
                      ),
                    ],
                    gap(),
                    _Stepper(
                      title: t.obfGrace,
                      value: _grace,
                      min: 0,
                      max: 14,
                      onChanged: (v) => setState(() => _grace = v),
                    ),
                    gap(),
                    _Stepper(
                      title: t.obfLead,
                      value: _lead,
                      min: 0,
                      max: 14,
                      onChanged: (v) => setState(() => _lead = v),
                    ),
                  ]),
                  card([
                    _TapRow(
                      title: t.obfCategory,
                      value: cat?.label(arabic: arabic) ?? t.obfNoCategory,
                      onTap: () => _pickCategory(cats, arabic),
                    ),
                    gap(),
                    label(t.obfMatchWords),
                    field(_words, hint: t.obfMatchHint),
                    gap(),
                    _Stepper(
                      title: t.obfTolerance,
                      value: _tolerance,
                      min: 0,
                      max: 50,
                      step: 5,
                      onChanged: (v) => setState(() => _tolerance = v),
                    ),
                    gap(),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            t.obfAuto,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: text,
                            ),
                          ),
                        ),
                        appSwitch(
                          context,
                          value: _auto,
                          onChanged: (v) => setState(() => _auto = v),
                        ),
                      ],
                    ),
                    note(t.obfAutoNote),
                  ]),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: AppTokens.danger.resolveFrom(context),
                          fontSize: 14,
                        ),
                      ),
                    ),
                  PrimaryButton(
                    label: t.obfSave,
                    busy: _busy,
                    onPressed: _save,
                  ),
                  const SizedBox(height: 32),
                ],
              ),
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.step = 1,
  });

  final String title;
  final int value;
  final int min;
  final int max;
  final int step;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final text = AppTokens.text.resolveFrom(context);
    // Outlined round buttons; at the limit the button is flat on the track colour with a muted sign.
    Widget btn(IconData icon, String label, bool on, VoidCallback f) =>
        CupertinoButton(
          pressedOpacity: 1,
          padding: EdgeInsets.zero,
          minimumSize: const Size(44, 44),
          onPressed: on ? f : null,
          child: PressShadow(
            enabled: on,
            decoration: BoxDecoration(
              color: on
                  ? AppTokens.card.resolveFrom(context)
                  : AppTokens.bar.resolveFrom(context),
              shape: BoxShape.circle,
              border: outlineOf(context, width: AppTokens.outlineThin),
            ),
            child: SizedBox(
              width: 34,
              height: 34,
              child: Icon(
                icon,
                size: 18,
                color: on ? text : AppTokens.muted.resolveFrom(context),
                semanticLabel: label,
              ),
            ),
          ),
        );
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: text,
            ),
          ),
        ),
        btn(LucideIcons.minus, '− $title', value > min, () {
          onChanged((value - step).clamp(min, max));
        }),
        Semantics(
          label: '$title $value',
          excludeSemantics: true,
          child: SizedBox(
            width: 36,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: text,
              ),
            ),
          ),
        ),
        btn(LucideIcons.plus, '+ $title', value < max, () {
          onChanged((value + step).clamp(min, max));
        }),
      ],
    );
  }
}

class _TapRow extends StatelessWidget {
  const _TapRow({
    required this.title,
    required this.value,
    required this.onTap,
  });

  final String title;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTokens.text.resolveFrom(context),
                  ),
                ),
              ),
              Flexible(
                child: Text(
                  value,
                  style: TextStyle(color: AppTokens.muted.resolveFrom(context)),
                ),
              ),
              ForwardChevron(
                size: 14,
                color: AppTokens.muted.resolveFrom(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
