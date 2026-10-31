import 'package:flutter/cupertino.dart';

import '../../core/models.dart';
import '../../core/money.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';

/// Amount + merchant + spent/received + time. Used by Quick add and by "Add as transaction" in the review inbox.
class ManualTxnForm extends StatefulWidget {
  const ManualTxnForm({
    super.key,
    required this.onSave,
    this.initialTime,
    this.initialMerchant,
  });

  final Future<void> Function(ManualTxn txn) onSave;
  final DateTime? initialTime;
  final String? initialMerchant;

  @override
  State<ManualTxnForm> createState() => _ManualTxnFormState();
}

class _ManualTxnFormState extends State<ManualTxnForm> {
  final _amount = TextEditingController();
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
    var picked = _when;
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => Container(
        height: 280,
        color: CupertinoColors.systemBackground.resolveFrom(ctx),
        child: SafeArea(
          top: false,
          child: CupertinoDatePicker(
            mode: CupertinoDatePickerMode.dateAndTime,
            use24hFormat: true,
            initialDateTime: _when,
            maximumDate: DateTime.now().add(const Duration(minutes: 1)),
            onDateTimeChanged: (d) => picked = d,
          ),
        ),
      ),
    );
    if (mounted) setState(() => _when = picked);
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
        CupertinoSlidingSegmentedControl<String>(
          groupValue: _direction,
          children: {
            'out': Padding(
              padding: const EdgeInsets.all(8),
              child: Text(t.qaSpent),
            ),
            'in': Padding(
              padding: const EdgeInsets.all(8),
              child: Text(t.qaReceived),
            ),
          },
          onValueChanged: (v) => setState(() => _direction = v ?? 'out'),
        ),
        const SizedBox(height: 16),
        CupertinoTextField(
          controller: _amount,
          placeholder: t.qaAmount,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          padding: const EdgeInsets.all(14),
        ),
        if (_invalid)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              t.qaAmountInvalid,
              style: TextStyle(
                color: AppColors.danger.resolveFrom(context),
                fontSize: 13,
              ),
            ),
          ),
        const SizedBox(height: 12),
        CupertinoTextField(
          controller: _merchant,
          placeholder: t.qaMerchant,
          padding: const EdgeInsets.all(14),
        ),
        const SizedBox(height: 12),
        CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _pickTime,
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Text('${t.qaWhen}: ${_fmt(_when)}'),
            ),
          ),
        ),
        if (_failed)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              t.qaSaveFailed,
              style: TextStyle(
                color: AppColors.danger.resolveFrom(context),
                fontSize: 13,
              ),
            ),
          ),
        const SizedBox(height: 20),
        CupertinoButton.filled(
          onPressed: _busy ? null : _save,
          child: _busy ? const CupertinoActivityIndicator() : Text(t.qaSave),
        ),
      ],
    );
  }
}
