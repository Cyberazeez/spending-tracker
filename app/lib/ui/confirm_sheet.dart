import 'package:flutter/cupertino.dart';

import '../l10n/app_localizations.dart';
import 'sheet_frame.dart';
import 'swipe_action.dart';
import '../core/money.dart' show riyalFont;
import 'icon_tile.dart';
import 'theme.dart';
import 'tokens.dart';
import 'press.dart';
import 'app_sheet.dart';

/// Asks a yes/no question in the app's bottom-sheet look, instead of the native alert.
/// Returns true for the confirm button, false for the cancel button, null when dismissed.
/// With [icon], the sheet is the centred kind of the design: a pastel tile ([iconColor]), the title and message
/// centred under it (mark as paid, delete my account). [cancelPrimary] draws the cancel button as the emerald one
/// (the safe choice of a destructive question, "Keep my account").
Future<bool?> showConfirmSheet(
  BuildContext context, {
  required String title,
  String? message,
  required String confirmLabel,
  String? cancelLabel,
  bool destructive = false,
  IconData? icon,
  Color? iconColor,
  bool cancelPrimary = false,
}) {
  final t = AppLocalizations.of(context);
  if (icon != null) {
    return showAppSheet<bool>(
      context: context,
      builder: (ctx) => _IconSheet(
        icon: icon,
        color: iconColor ?? AppTokens.gold.resolveFrom(ctx),
        title: title,
        message: message,
        buttons: [
          _SheetButton(
            key: const ValueKey('confirm-yes'),
            label: confirmLabel,
            primary: true,
            destructive: destructive,
            onTap: () => Navigator.pop(ctx, true),
          ),
          _SheetButton(
            key: const ValueKey('confirm-no'),
            label: cancelLabel ?? t.cancel,
            primary: cancelPrimary,
            onTap: () => Navigator.pop(ctx, false),
          ),
        ],
      ),
    );
  }
  return showAppSheet<bool>(
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
/// With [icon], the centred kind (a pastel tile over the title): say "done" with a mint check, a failure with a
/// coral warning.
Future<void> showNoticeSheet(
  BuildContext context, {
  required String title,
  String? message,
  String? okLabel,
  IconData? icon,
  Color? iconColor,
}) {
  final t = AppLocalizations.of(context);
  if (icon != null) {
    return showAppSheet<void>(
      context: context,
      builder: (ctx) => _IconSheet(
        icon: icon,
        color: iconColor ?? AppTokens.gold.resolveFrom(ctx),
        title: title,
        message: message,
        buttons: [
          _SheetButton(
            label: okLabel ?? t.done,
            primary: true,
            onTap: () => Navigator.pop(ctx),
          ),
        ],
      ),
    );
  }
  return showAppSheet<void>(
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

/// The centred sheet: grabber, a 64 pt pastel tile, the title and message centred, the buttons.
class _IconSheet extends StatelessWidget {
  const _IconSheet({
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
    required this.buttons,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String? message;
  final List<Widget> buttons;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final text = AppTokens.text.resolveFrom(context);
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        constraints: BoxConstraints(maxHeight: media.size.height * 0.9),
        decoration: BoxDecoration(
          color: AppTokens.bg.resolveFrom(context),
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppTokens.radiusSheet),
          ),
          border: outlineOf(context),
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 10, 20, media.padding.bottom + 16),
          child: DefaultTextStyle(
            style: TextStyle(
              color: text,
              fontSize: 15,
              inherit: false,
              fontFamily: appFont,
              fontFamilyFallback: const [riyalFont],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppTokens.line
                          .resolveFrom(context)
                          .withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Center(
                  child: IconTile(
                    color: color,
                    icon: icon,
                    size: 64,
                    radius: 16,
                    iconSize: 30,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: text,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    decoration: TextDecoration.none,
                  ),
                ),
                if (message != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    message!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTokens.muted.resolveFrom(context),
                      fontSize: 15,
                      height: 1.45,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                for (var i = 0; i < buttons.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  buttons[i],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SheetButton extends StatelessWidget {
  const _SheetButton({
    super.key,
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
              ? swipeLabelColor(AppColors.danger.resolveFrom(context))
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
        // The (3, 4) shadow stays inside the button's own box.
        child: Padding(
          padding: const EdgeInsets.only(right: 3, bottom: 4),
          child: Pressable(
            offset: const Offset(3, 4),
            builder: (context, depth) => Container(
              constraints: const BoxConstraints(minHeight: 50),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(26),
                border: outlineOf(context),
                boxShadow: hardShadowOf(
                  context,
                  offset: const Offset(3, 4) * (1 - depth),
                ),
              ),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: fg,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
