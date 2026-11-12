import 'package:flutter/cupertino.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'sheet_frame.dart';
import 'theme.dart';
import 'tokens.dart';
import 'press.dart';
import 'app_sheet.dart';

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
  return showAppSheet<T>(
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
            for (final o in options)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _Row<T>(option: o, ring: options.any((o) => o.selected)),
              ),
          ],
        ),
      ),
    ),
  );
}

class _Row<T> extends StatelessWidget {
  const _Row({required this.option, required this.ring});
  final ChoiceOption<T> option;

  /// Draw the radio ring: only when one of the options is the current one (a language, a filter), not on a list of
  /// actions.
  final bool ring;

  @override
  Widget build(BuildContext context) {
    final color = option.destructive
        ? AppColors.danger.resolveFrom(context)
        : AppTokens.text.resolveFrom(context);
    final line = AppTokens.line.resolveFrom(context);
    final selected = option.selected;
    return Semantics(
      button: true,
      selected: selected,
      label: option.label,
      excludeSemantics: true,
      onTap: () => Navigator.pop(context, option.value),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.pop(context, option.value),
        child: Padding(
          padding: const EdgeInsets.only(right: 3, bottom: 4),
          child: Pressable(
            offset: const Offset(3, 4),
            enabled: true,
            builder: (context, depth) => DecoratedBox(
              decoration: BoxDecoration(
                color: AppTokens.card.resolveFrom(context),
                borderRadius: BorderRadius.circular(AppTokens.radiusCard),
                border: outlineOf(context),
                boxShadow: selected
                    ? hardShadowOf(
                        context,
                        offset: const Offset(3, 4) * (1 - depth),
                      )
                    : null,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 54),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
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
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                      if (ring) ...[
                        const SizedBox(width: 10),
                        Container(
                          key: selected
                              ? const ValueKey('choice-selected')
                              : null,
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: selected
                                ? AppTokens.accent.resolveFrom(context)
                                : null,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: line,
                              width: AppTokens.outlineThin,
                            ),
                          ),
                          child: selected
                              ? Icon(
                                  LucideIcons.check,
                                  size: 16,
                                  color: AppTokens.onAccent.resolveFrom(
                                    context,
                                  ),
                                )
                              : null,
                        ),
                      ],
                    ],
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
