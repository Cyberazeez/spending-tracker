import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../router.dart';
import 'header_button.dart';
import 'tokens.dart';
import 'press.dart';

/// Navigation bar of the sub-screens: the page colour, no line, and an outlined back button (key `nav-back`) that
/// pops the screen (so the swipe from the left edge and the button do the same thing).
CupertinoNavigationBar appNavBar(BuildContext context, String title) =>
    CupertinoNavigationBar(
      backgroundColor: AppTokens.bg.resolveFrom(context),
      border: null,
      middle: Text(
        title,
        style: TextStyle(
          color: AppTokens.text.resolveFrom(context),
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      leading: Align(
        alignment: AlignmentDirectional.centerStart,
        widthFactor: 1,
        child: HeaderIconButton(
          key: const ValueKey('nav-back'),
          onPressed: () => popOrHome(context),
          fill: AppTokens.card.resolveFrom(context),
          icon: Directionality.of(context) == TextDirection.rtl
              ? LucideIcons.chevronRight
              : LucideIcons.chevronLeft,
          iconColor: AppTokens.text.resolveFrom(context),
          semanticLabel: CupertinoLocalizations.of(context).backButtonLabel,
        ),
      ),
    );

/// The main action of a screen: a full-width accent pill.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;
    final accent = AppTokens.accent.resolveFrom(context);
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      onTap: enabled ? onPressed : null,
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: const Size(44, 52),
        pressedOpacity: 1, // the box presses into its shadow instead
        onPressed: enabled ? onPressed : null,
        child: Padding(
          padding: const EdgeInsets.only(right: 3, bottom: 4),
          child: Pressable(
            offset: const Offset(3, 4),
            enabled: enabled,
            builder: (context, depth) => DecoratedBox(
              decoration: BoxDecoration(
                color: enabled ? accent : AppTokens.bar.resolveFrom(context),
                borderRadius: BorderRadius.circular(26),
                border: outlineOf(context),
                boxShadow: enabled
                    ? hardShadowOf(
                        context,
                        offset: const Offset(3, 4) * (1 - depth),
                      )
                    : null,
              ),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: Center(
                  child: busy
                      ? CupertinoActivityIndicator(
                          color: AppTokens.onAccent.resolveFrom(context),
                        )
                      : Text(
                          label,
                          style: TextStyle(
                            color: enabled
                                ? AppTokens.onAccent.resolveFrom(context)
                                : AppTokens.muted.resolveFrom(context),
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A second action next to or under a [PrimaryButton]: a card-coloured pill with the outline and the hard shadow.
/// [danger] draws the label in the danger colour (remove, delete).
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.danger = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool danger;

  /// Drawn before the label, in the label's colour.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final color = !enabled
        ? AppTokens.muted.resolveFrom(context)
        : danger
        ? AppTokens.danger.resolveFrom(context)
        : AppTokens.text.resolveFrom(context);
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      onTap: onPressed,
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: const Size(44, 48),
        pressedOpacity: 1,
        onPressed: onPressed,
        child: Padding(
          padding: const EdgeInsets.only(right: 3, bottom: 4),
          child: Pressable(
            offset: const Offset(3, 4),
            enabled: enabled,
            builder: (context, depth) => DecoratedBox(
              decoration: BoxDecoration(
                color: AppTokens.card.resolveFrom(context),
                borderRadius: BorderRadius.circular(26),
                border: outlineOf(context),
                boxShadow: enabled
                    ? hardShadowOf(
                        context,
                        offset: const Offset(3, 4) * (1 - depth),
                      )
                    : null,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minWidth: double.infinity,
                  minHeight: 48,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (icon != null) ...[
                          Icon(icon, size: 18, color: color),
                          const SizedBox(width: 8),
                        ],
                        Flexible(
                          child: Text(
                            label,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: color,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A tappable row drawn like a text field (card fill, outline, 14 pt corners, 50 pt tall) for values chosen from a
/// picker, such as a date.
class FieldButton extends StatelessWidget {
  const FieldButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final muted = AppTokens.muted.resolveFrom(context);
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onPressed,
      // CupertinoButton for the same pressed feedback the old text button had.
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: const Size(44, 50),
        onPressed: onPressed,
        child: Container(
          constraints: const BoxConstraints(minHeight: 50),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppTokens.card.resolveFrom(context),
            borderRadius: BorderRadius.circular(14),
            border: outlineOf(context),
          ),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: muted),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: AppTokens.text.resolveFrom(context),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A text field in the card style with an optional label above it.
class AppField extends StatelessWidget {
  const AppField({
    super.key,
    required this.controller,
    this.label,
    this.placeholder,
    this.obscure = false,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.onSubmitted,
    this.autofocus = false,
    this.inputFormatters,
    this.large = false,
  });

  final List<TextInputFormatter>? inputFormatters;

  /// A big, heavy value (the amount of a new transaction).
  final bool large;
  final TextEditingController controller;
  final String? label;
  final String? placeholder;
  final bool obscure;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final field = CupertinoTextField(
      controller: controller,
      placeholder: placeholder,
      obscureText: obscure,
      autocorrect: !obscure && keyboardType != TextInputType.emailAddress,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      onSubmitted: onSubmitted,
      autofocus: autofocus,
      inputFormatters: inputFormatters,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      style: TextStyle(
        color: AppTokens.text.resolveFrom(context),
        fontSize: large ? 24 : 16,
        fontWeight: large ? FontWeight.w800 : FontWeight.w500,
        fontFeatures: large ? const [FontFeature.tabularFigures()] : null,
      ),
      placeholderStyle: TextStyle(
        color: AppTokens.muted.resolveFrom(context),
        fontSize: large ? 24 : 16,
        fontWeight: large ? FontWeight.w800 : FontWeight.w500,
      ),
      decoration: BoxDecoration(
        color: AppTokens.card.resolveFrom(context),
        borderRadius: BorderRadius.circular(14),
        border: outlineOf(context),
      ),
    );
    if (label == null) {
      return Semantics(label: placeholder, textField: true, child: field);
    }
    return Semantics(
      label: label,
      textField: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: Padding(
              padding: const EdgeInsetsDirectional.only(start: 4, bottom: 6),
              child: Text(
                label!,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTokens.text.resolveFrom(context),
                ),
              ),
            ),
          ),
          field,
        ],
      ),
    );
  }
}

/// Small red message under a field or button.
class FormError extends StatelessWidget {
  const FormError(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8, left: 4, right: 4),
    child: Text(
      text,
      style: TextStyle(
        color: AppTokens.danger.resolveFrom(context),
        fontSize: 13,
      ),
    ),
  );
}
