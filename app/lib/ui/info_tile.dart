import 'package:flutter/cupertino.dart';

/// A list row like [CupertinoListTile] that still fits when the owner turns text size up: past 1.3x the amount drops
/// under the title instead of squeezing it, and long titles wrap rather than overflow.
class InfoTile extends StatelessWidget {
  const InfoTile({
    super.key,
    required this.title,
    this.subtitle,
    this.additionalInfo,
    this.leading,
    this.trailing,
    this.onTap,
  });

  final Widget title;
  final Widget? subtitle;
  final Widget? additionalInfo;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final base = CupertinoTheme.of(context).textTheme.textStyle;
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);
    final stacked = MediaQuery.textScalerOf(context).scale(10) > 13;

    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        DefaultTextStyle(style: base.copyWith(fontSize: 17), child: title),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          DefaultTextStyle(
            style: base.copyWith(fontSize: 14, color: secondary),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            child: subtitle!,
          ),
        ],
        if (stacked && additionalInfo != null) ...[
          const SizedBox(height: 4),
          DefaultTextStyle(
            style: base.copyWith(fontSize: 17, color: secondary),
            child: additionalInfo!,
          ),
        ],
      ],
    );

    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (leading != null) ...[
          SizedBox.square(dimension: 28, child: Center(child: leading)),
          const SizedBox(width: 12),
        ],
        Expanded(child: titleBlock),
        if (!stacked && additionalInfo != null) ...[
          const SizedBox(width: 8),
          // The amount keeps its full width; the title wraps instead.
          DefaultTextStyle(
            style: base.copyWith(fontSize: 17, color: secondary),
            maxLines: 1,
            softWrap: false,
            child: additionalInfo!,
          ),
        ],
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
      ],
    );

    final tile = ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: 44,
        minWidth: double.infinity,
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(20, 10, 14, 10),
        child: row,
      ),
    );
    if (onTap == null) return tile;
    return Semantics(
      button: true,
      container: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: tile,
      ),
    );
  }
}
