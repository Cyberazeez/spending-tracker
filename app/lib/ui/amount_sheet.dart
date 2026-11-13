import 'package:flutter/cupertino.dart';

import '../core/money.dart';
import '../l10n/app_localizations.dart';
import 'app_form.dart';
import 'sheet_frame.dart';
import 'tokens.dart';
import 'app_sheet.dart';
import 'press.dart';

/// Asks for an amount in the app's bottom-sheet look: a big centred amount with the riyal sign, quick amounts to tap
/// (the one typed is highlighted) and a Save button. Returns halalas, or null when dismissed.
Future<int?> showAmountSheet(
  BuildContext context, {
  required String title,
  String? subtitle,
  int? initialHalalas,
  List<int> suggestionsHalalas = const [],
  required int maxHalalas,
  required String invalidText,
}) async {
  final r = await showAppSheet<Object>(
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
  return r is int ? r : null;
}

/// What [showAmountSheetOrRemove] returned: a new amount, or that the person chose [removeLabel].
sealed class AmountChoice {}

class AmountSet extends AmountChoice {
  AmountSet(this.halalas);
  final int halalas;
}

class AmountRemoved extends AmountChoice {}

/// [showAmountSheet] with a red text link under Save ([removeLabel], shown when given) that removes the amount (the
/// monthly budget).
Future<AmountChoice?> showAmountSheetOrRemove(
  BuildContext context, {
  required String title,
  int? initialHalalas,
  List<int> suggestionsHalalas = const [],
  required int maxHalalas,
  required String invalidText,
  String? removeLabel,
}) async {
  final r = await showAppSheet<Object>(
    context: context,
    builder: (ctx) => _AmountSheet(
      title: title,
      subtitle: null,
      initialHalalas: initialHalalas,
      suggestions: suggestionsHalalas,
      maxHalalas: maxHalalas,
      invalidText: invalidText,
      removeLabel: removeLabel,
    ),
  );
  return switch (r) {
    final int v => AmountSet(v),
    _removed => AmountRemoved(),
    _ => null,
  };
}

/// Popped by the remove link.
const _removed = #removed;

class _AmountSheet extends StatefulWidget {
  const _AmountSheet({
    required this.title,
    required this.subtitle,
    required this.initialHalalas,
    required this.suggestions,
    required this.maxHalalas,
    required this.invalidText,
    this.removeLabel,
  });
  final String? removeLabel;
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
            // The amount, centred and large on the page colour: "⃁ 6,000".
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppTokens.bg.resolveFrom(context),
                borderRadius: BorderRadius.circular(AppTokens.radiusCard),
                border: Border.all(
                  color: _invalid
                      ? AppTokens.danger.resolveFrom(context)
                      : AppTokens.line.resolveFrom(context),
                  width: AppTokens.outline,
                ),
              ),
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      riyalSign,
                      style: TextStyle(
                        color: muted,
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: IntrinsicWidth(
                        child: CupertinoTextField(
                          key: const ValueKey('amount-field'),
                          controller: _c,
                          autofocus: true,
                          placeholder: '0',
                          textAlign: TextAlign.center,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _save(),
                          onChanged: (_) => setState(() => _invalid = false),
                          decoration: null,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          style: TextStyle(
                            color: text,
                            fontSize: 44,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
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
                  alignment: WrapAlignment.center,
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
                        child: PressShadow(
                          decoration: BoxDecoration(
                            color: parseHalalas(_c.text) == s
                                ? AppTokens.accent.resolveFrom(context)
                                : card,
                            borderRadius: BorderRadius.circular(22),
                            border: outlineOf(
                              context,
                              width: AppTokens.outlineThin,
                            ),
                          ),
                          // Sized to its label (an alignment here would stretch it across the sheet).
                          child: Container(
                            constraints: const BoxConstraints(minHeight: 44),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            child: Center(
                              widthFactor: 1,
                              child: Text(
                                (s / 100)
                                    .toStringAsFixed(0)
                                    .replaceAllMapped(
                                      RegExp(r'\B(?=(\d{3})+(?!\d))'),
                                      (m) => ',',
                                    ),
                                style: TextStyle(
                                  color: parseHalalas(_c.text) == s
                                      ? AppTokens.onAccent.resolveFrom(context)
                                      : text,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 18),
            PrimaryButton(
              key: const ValueKey('amount-save'),
              label: t.insSave,
              onPressed: _save,
            ),
            if (widget.removeLabel != null)
              CupertinoButton(
                key: const ValueKey('amount-remove'),
                minimumSize: const Size(44, 44),
                onPressed: () => Navigator.pop(context, _removed),
                child: Text(
                  widget.removeLabel!,
                  style: TextStyle(
                    color: AppTokens.danger.resolveFrom(context),
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
