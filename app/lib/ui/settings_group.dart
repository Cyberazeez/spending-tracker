import 'package:flutter/cupertino.dart';

import 'app_card.dart';
import 'tokens.dart';

/// A titled card of [SettingsRow]s separated by hairlines (the More tab and its sub-screens).
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, required this.children, this.title});

  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final line = AppTokens.muted.resolveFrom(context).withValues(alpha: 0.18);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 6, bottom: 8),
            child: Text(
              title!,
              style: TextStyle(
                color: AppTokens.muted.resolveFrom(context),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                children[i],
                if (i < children.length - 1)
                  SizedBox(height: 1, child: ColoredBox(color: line)),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// One setting: a colored rounded icon tile, a title, an optional subtitle and either a value + chevron or a control.
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    this.subtitle,
    this.value,
    this.control,
    this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final String? value;

  /// A switch or similar; replaces the chevron.
  final Widget? control;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final text = danger
        ? AppTokens.danger.resolveFrom(context)
        : AppTokens.text.resolveFrom(context);
    final muted = AppTokens.muted.resolveFrom(context);
    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: danger
                    ? AppTokens.danger
                          .resolveFrom(context)
                          .withValues(alpha: 0.16)
                    : color,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(
                icon,
                size: 19,
                color: danger
                    ? AppTokens.danger.resolveFrom(context)
                    : const Color(0xFF0B0F14),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: text,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty)
                    Text(
                      subtitle!,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: muted, fontSize: 12),
                    ),
                ],
              ),
            ),
            if (value != null) ...[
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 140),
                child: Text(
                  value!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: TextStyle(color: muted, fontSize: 14),
                ),
              ),
            ],
            if (control != null) ...[
              const SizedBox(width: 8),
              control!,
            ] else if (onTap != null && !danger) ...[
              const SizedBox(width: 6),
              Icon(CupertinoIcons.chevron_forward, size: 14, color: muted),
            ],
          ],
        ),
      ),
    );
    if (onTap == null) {
      return Semantics(container: true, label: title, child: row);
    }
    return Semantics(
      container: true,
      button: true,
      onTap: onTap,
      label: [title, ?subtitle, ?value].join(', '),
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: row,
        ),
      ),
    );
  }
}
