import 'package:flutter/cupertino.dart';

import '../l10n/app_localizations.dart';
import 'sheet_frame.dart';
import 'theme.dart';
import 'tokens.dart';

/// Asks a yes/no question in the app's bottom-sheet look, instead of the native alert.
/// Returns true for the confirm button, false for the cancel button, null when dismissed.
Future<bool?> showConfirmSheet(
  BuildContext context, {
  required String title,
  String? message,
  required String confirmLabel,
  String? cancelLabel,
  bool destructive = false,
}) {
  final t = AppLocalizations.of(context);
  return showCupertinoModalPopup<bool>(
    context: context,
    builder: (ctx) => SheetFrame(
      title: title,
      child: _Body(
        message: message,
        buttons: [
          _SheetButton(
            label: confirmLabel,
            primary: true,
            destructive: destructive,
            onTap: () => Navigator.pop(ctx, true),
          ),
          _SheetButton(
            label: cancelLabel ?? t.cancel,
            onTap: () => Navigator.pop(ctx, false),
          ),
        ],
      ),
    ),
  );
}

/// Tells the person something (a failure, a result) with one button, in the same look.
Future<void> showNoticeSheet(
  BuildContext context, {
  required String title,
  String? message,
  String? okLabel,
}) {
  final t = AppLocalizations.of(context);
  return showCupertinoModalPopup<void>(
    context: context,
    builder: (ctx) => SheetFrame(
      title: title,
      child: _Body(
        message: message,
        buttons: [
          _SheetButton(
            label: okLabel ?? t.done,
            primary: true,
            onTap: () => Navigator.pop(ctx),
          ),
        ],
      ),
    ),
  );
}

class _Body extends StatelessWidget {
  const _Body({required this.message, required this.buttons});
  final String? message;
  final List<Widget> buttons;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (message != null)
            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 14),
              child: Text(
                message!,
                style: TextStyle(
                  color: AppTokens.muted.resolveFrom(context),
                  fontSize: 15,
                  height: 1.35,
                  decoration: TextDecoration.none,
                ),
              ),
            )
          else
            const SizedBox(height: 10),
          for (var i = 0; i < buttons.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            buttons[i],
          ],
        ],
      ),
    );
  }
}

class _SheetButton extends StatelessWidget {
  const _SheetButton({
    required this.label,
    required this.onTap,
    this.primary = false,
    this.destructive = false,
  });
  final String label;
  final VoidCallback onTap;
  final bool primary;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final bg = primary
        ? (destructive
              ? AppColors.danger.resolveFrom(context)
              : AppTokens.accent.resolveFrom(context))
        : AppTokens.card.resolveFrom(context);
    final fg = primary
        ? (destructive
              ? const Color(0xFFFFFFFF)
              : AppTokens.onAccent.resolveFrom(context))
        : AppTokens.text.resolveFrom(context);
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 50),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: fg,
              fontSize: 17,
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ),
    );
  }
}
