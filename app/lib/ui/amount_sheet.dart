import 'package:flutter/cupertino.dart';

import '../core/money.dart';
import '../l10n/app_localizations.dart';
import 'app_form.dart';
import 'sheet_frame.dart';
import 'tokens.dart';

/// Asks for an amount in the app's bottom-sheet look: a big field with the riyal sign, quick amounts to tap and a
/// Save button. Returns halalas, or null when dismissed.
Future<int?> showAmountSheet(
  BuildContext context, {
  required String title,
  String? subtitle,
  int? initialHalalas,
  List<int> suggestionsHalalas = const [],
  required int maxHalalas,
  required String invalidText,
}) {
  return showCupertinoModalPopup<int>(
    context: context,
    builder: (ctx) => _AmountSheet(
      title: title,
      subtitle: subtitle,
      initialHalalas: initialHalalas,
      suggestions: suggestionsHalalas,
      maxHalalas: maxHalalas,
      invalidText: invalidText,
    ),
  );
}

class _AmountSheet extends StatefulWidget {
  const _AmountSheet({
    required this.title,
    required this.subtitle,
    required this.initialHalalas,
    required this.suggestions,
    required this.maxHalalas,
    required this.invalidText,
  });
  final String title;
  final String? subtitle;
  final int? initialHalalas;
  final List<int> suggestions;
  final int maxHalalas;
  final String invalidText;

  @override
  State<_AmountSheet> createState() => _AmountSheetState();
}

class _AmountSheetState extends State<_AmountSheet> {
  late final TextEditingController _c = TextEditingController(
    text: widget.initialHalalas == null
        ? ''
        : (widget.initialHalalas! / 100).toStringAsFixed(
            widget.initialHalalas! % 100 == 0 ? 0 : 2,
          ),
  );
  bool _invalid = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _save() {
    final v = parseHalalas(_c.text);
    if (v == null || v > widget.maxHalalas) {
      setState(() => _invalid = true);
      return;
    }
    Navigator.pop(context, v);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final card = AppTokens.card.resolveFrom(context);
    final text = AppTokens.text.resolveFrom(context);
    final muted = AppTokens.muted.resolveFrom(context);
    return SheetFrame(
      title: widget.title,
      subtitle: widget.subtitle,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: card,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: _invalid
                      ? AppTokens.danger.resolveFrom(context)
                      : const Color(0x00000000),
                  width: 1.5,
                ),
              ),
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: Row(
                  children: [
                    Text(
                      riyalSign,
                      style: TextStyle(
                        color: muted,
                        fontSize: 26,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: CupertinoTextField(
                        controller: _c,
                        autofocus: true,
                        placeholder: '0',
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _save(),
                        onChanged: (_) {
                          if (_invalid) setState(() => _invalid = false);
                        },
                        decoration: null,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        style: TextStyle(
                          color: text,
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_invalid)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  widget.invalidText,
                  style: TextStyle(
                    color: AppTokens.danger.resolveFrom(context),
                    fontSize: 13,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            if (widget.suggestions.isNotEmpty) ...[
              const SizedBox(height: 14),
              Directionality(
                textDirection: TextDirection.ltr,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final s in widget.suggestions)
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => setState(() {
                          _invalid = false;
                          _c.text = (s / 100).toStringAsFixed(0);
                          _c.selection = TextSelection.collapsed(
                            offset: _c.text.length,
                          );
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: card,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Text(
                            (s / 100)
                                .toStringAsFixed(0)
                                .replaceAllMapped(
                                  RegExp(r'\B(?=(\d{3})+(?!\d))'),
                                  (m) => ',',
                                ),
                            style: TextStyle(
                              color: AppTokens.accentText.resolveFrom(context),
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 18),
            PrimaryButton(label: t.insSave, onPressed: _save),
          ],
        ),
      ),
    );
  }
}
