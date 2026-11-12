import 'package:flutter/cupertino.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'app_card.dart';
import 'sheet_frame.dart';
import 'theme.dart';
import 'tokens.dart';

class ChoiceOption<T> {
  const ChoiceOption({
    required this.value,
    required this.label,
    this.icon,
    this.selected = false,
    this.destructive = false,
  });

  final T value;
  final String label;
  final IconData? icon;

  /// Marked with a check (the current language, for instance).
  final bool selected;
  final bool destructive;
}

/// A short list of choices in the app's bottom-sheet look, instead of the native action sheet.
/// Returns the chosen value, or null when dismissed.
Future<T?> showChoiceSheet<T>(
  BuildContext context, {
  required String title,
  String? subtitle,
  String? message,
  required List<ChoiceOption<T>> options,
}) {
  return showCupertinoModalPopup<T>(
    context: context,
    builder: (ctx) => SheetFrame(
      title: title,
      subtitle: subtitle,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (message != null)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTokens.bg.resolveFrom(ctx),
                  borderRadius: BorderRadius.circular(12),
                  border: outlineOf(ctx, width: AppTokens.outlineThin),
                ),
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text(
                    message,
                    style: TextStyle(
                      color: AppTokens.muted.resolveFrom(ctx),
                      fontSize: 14,
                      height: 1.35,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < options.length; i++) ...[
                    _Row<T>(option: options[i]),
                    if (i < options.length - 1)
                      Container(
                        height: 2,
                        margin: const EdgeInsets.symmetric(horizontal: 14),
                        color: AppTokens.bar.resolveFrom(ctx),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _Row<T> extends StatelessWidget {
  const _Row({required this.option});
  final ChoiceOption<T> option;

  @override
  Widget build(BuildContext context) {
    final color = option.destructive
        ? AppColors.danger.resolveFrom(context)
        : AppTokens.text.resolveFrom(context);
    return Semantics(
      button: true,
      selected: option.selected,
      label: option.label,
      excludeSemantics: true,
      onTap: () => Navigator.pop(context, option.value),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.pop(context, option.value),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 54),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                if (option.icon != null) ...[
                  Icon(option.icon, size: 20, color: color),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Text(
                    option.label,
                    style: TextStyle(
                      color: color,
                      fontSize: 17,
                      fontWeight: option.selected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
                if (option.selected)
                  Icon(
                    LucideIcons.check,
                    size: 20,
                    color: AppTokens.accentText.resolveFrom(context),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
