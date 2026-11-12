import 'package:flutter/cupertino.dart';

import 'chevron.dart';
import 'icon_tile.dart';
import 'press.dart';

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
          // Rows carry their own side padding so a pressed row's highlight reaches close to the card's sides.
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                children[i],
                if (i < children.length - 1)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: SizedBox(height: 2, child: ColoredBox(color: line)),
                  ),
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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
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
    // 6 + 8 = the 14 pt side padding the rows always had.
    const side = EdgeInsets.symmetric(horizontal: 6);
    if (onTap == null) {
      return Semantics(
        container: true,
        label: title,
        child: Padding(padding: side, child: row),
      );
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
          child: Padding(
            padding: side,
            child: PressHighlight(child: row),
          ),
        ),
      ),
    );
  }
}

/// The app's on/off switch: the native switch (it keeps its own thumb slide and drag) with an outlined track
/// (emerald when on, `bar` when off) and a small hard shadow it presses into, like the app's buttons.
Widget appSwitch(
  BuildContext context, {
  required bool value,
  required ValueChanged<bool>? onChanged,
}) {
  final line = AppTokens.line.resolveFrom(context);
  final sw = CupertinoSwitch(
    value: value,
    onChanged: onChanged,
    activeTrackColor: AppTokens.accent.resolveFrom(context),
    inactiveTrackColor: AppTokens.bar.resolveFrom(context),
    trackOutlineColor: WidgetStatePropertyAll(line),
    trackOutlineWidth: const WidgetStatePropertyAll(AppTokens.outlineThin),
  );
  // The switch lays out 59 x 39 with its 51 x 31 track in the middle, so the 2 x 3 shadow fits in that margin.
  const shadow = Offset(2, 3);
  return Pressable(
    offset: shadow,
    enabled: onChanged != null,
    builder: (context, depth) => Stack(
      children: [
        Positioned(
          left: 4 + shadow.dx * (1 - depth),
          top: 4 + shadow.dy * (1 - depth),
          width: 51,
          height: 31,
          child: DecoratedBox(
            key: const ValueKey('switch-shadow'),
            decoration: BoxDecoration(
              color: line,
              borderRadius: BorderRadius.circular(15.5),
            ),
          ),
        ),
        sw,
      ],
    ),
  );
}
