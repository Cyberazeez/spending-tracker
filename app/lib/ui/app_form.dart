import 'package:flutter/cupertino.dart';

import '../router.dart';
import 'tokens.dart';

/// Navigation bar of the sub-screens: the page colour, no line, and a back button that pops the screen (so the
/// swipe from the left edge and the button do the same thing).
CupertinoNavigationBar appNavBar(BuildContext context, String title) =>
    CupertinoNavigationBar(
      backgroundColor: AppTokens.bg.resolveFrom(context),
      border: null,
      middle: Text(title),
      leading: CupertinoNavigationBarBackButton(
        onPressed: () => popOrHome(context),
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
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: const Size(44, 52),
      onPressed: enabled ? onPressed : null,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: enabled ? accent : accent.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(26),
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
                      color: AppTokens.onAccent.resolveFrom(context),
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
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
  });

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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      style: TextStyle(
        color: AppTokens.text.resolveFrom(context),
        fontSize: 16,
      ),
      placeholderStyle: TextStyle(
        color: AppTokens.muted.resolveFrom(context),
        fontSize: 16,
      ),
      decoration: BoxDecoration(
        color: AppTokens.card.resolveFrom(context),
        borderRadius: BorderRadius.circular(16),
      ),
    );
    if (label == null) return field;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 4, bottom: 6),
          child: Text(
            label!,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTokens.muted.resolveFrom(context),
            ),
          ),
        ),
        field,
      ],
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
