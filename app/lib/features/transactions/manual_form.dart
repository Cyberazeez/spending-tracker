import 'package:flutter/cupertino.dart';

import '../../core/models.dart';
import '../../core/money.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/app_form.dart';
import '../../ui/sheet_frame.dart';
import '../../ui/tokens.dart';
import '../obligations/widgets/bills_widgets.dart';

/// Amount + merchant + spent/received + time. Used by Quick add and by "Add as transaction" in the review inbox.
class ManualTxnForm extends StatefulWidget {
  const ManualTxnForm({
    super.key,
    required this.onSave,
    this.initialTime,
    this.initialMerchant,
    this.initialAmount,
  });

  final Future<void> Function(ManualTxn txn) onSave;
  final DateTime? initialTime;
  final String? initialMerchant;

  /// Amount text to start with (a guess read from an unparsed SMS); the person can change it.
  final String? initialAmount;

  @override
  State<ManualTxnForm> createState() => _ManualTxnFormState();
}

class _ManualTxnFormState extends State<ManualTxnForm> {
  late final TextEditingController _amount = TextEditingController(
    text: widget.initialAmount,
  );
  late final TextEditingController _merchant = TextEditingController(
    text: widget.initialMerchant,
  );
  late DateTime _when = (widget.initialTime ?? DateTime.now()).toLocal();
  String _direction = 'out';
  bool _busy = false;
  bool _invalid = false;
  bool _failed = false;

  @override
  void dispose() {
    _amount.dispose();
    _merchant.dispose();
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
        ),
      );
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickTime() async {
    final t = AppLocalizations.of(context);
    var picked = _when;
    final result = await showCupertinoModalPopup<DateTime>(
      context: context,
      builder: (ctx) => SheetFrame(
        title: t.qaWhen,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 216,
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.dateAndTime,
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

  String _fmt(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}  ${two(d.hour)}:${two(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        PillSegments<String>(
          value: _direction,
          labels: {'out': t.qaSpent, 'in': t.qaReceived},
          onChanged: (v) => setState(() => _direction = v),
        ),
        const SizedBox(height: 16),
        AppField(
          controller: _amount,
          placeholder: t.qaAmount,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        if (_invalid) FormError(t.qaAmountInvalid),
        const SizedBox(height: 12),
        AppField(controller: _merchant, placeholder: t.qaMerchant),
        const SizedBox(height: 12),
        CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _pickTime,
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Text(
                '${t.qaWhen}: ${_fmt(_when)}',
                style: TextStyle(
                  color: AppTokens.accentText.resolveFrom(context),
                ),
              ),
            ),
          ),
        ),
        if (_failed) FormError(t.qaSaveFailed),
        const SizedBox(height: 20),
        PrimaryButton(label: t.qaSave, busy: _busy, onPressed: _save),
      ],
    );
  }
}
