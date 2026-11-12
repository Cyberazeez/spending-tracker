import 'package:flutter/cupertino.dart';

import 'chevron.dart';
import 'icon_tile.dart';

import 'app_card.dart';
import 'tokens.dart';

/// A titled card of [SettingsRow]s separated by hairlines (the More tab and its sub-screens).
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, required this.children, this.title});

  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final line = AppTokens.bar.resolveFrom(context);
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
                fontSize: 14,
                fontWeight: FontWeight.w700,
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
                  SizedBox(height: 2, child: ColoredBox(color: line)),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// The pink tile of a destructive row (sign out, delete my account); light in both modes, icon in ink.
const dangerTileColor = Color(0xFFFF9DB0);

/// One setting: a pastel [IconTile] (pass one of the palette fills; its icon is ink), a title, an optional subtitle and either a value + chevron or a control.
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
            IconTile(
              color: danger ? dangerTileColor : color,
              icon: icon,
              size: 38,
              iconSize: 19,
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
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty)
                    Text(
                      subtitle!,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: muted,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
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
                  style: TextStyle(
                    color: muted,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
            if (control != null) ...[
              const SizedBox(width: 8),
              control!,
            ] else if (onTap != null && !danger) ...[
              const SizedBox(width: 6),
              ForwardChevron(size: 14, color: muted),
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

/// The app's on/off switch: the native switch with an outlined track (emerald when on, `bar` when off).
CupertinoSwitch appSwitch(
  BuildContext context, {
  required bool value,
  required ValueChanged<bool>? onChanged,
}) {
  final line = AppTokens.line.resolveFrom(context);
  return CupertinoSwitch(
    value: value,
    onChanged: onChanged,
    activeTrackColor: AppTokens.accent.resolveFrom(context),
    inactiveTrackColor: AppTokens.bar.resolveFrom(context),
    trackOutlineColor: WidgetStatePropertyAll(line),
    trackOutlineWidth: const WidgetStatePropertyAll(AppTokens.outlineThin),
  );
}
