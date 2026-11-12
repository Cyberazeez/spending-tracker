import 'package:flutter/cupertino.dart';

import 'tokens.dart';

/// A category tile: a pastel rounded square with the ink outline and an ink icon. The fills are light in both
/// modes, so the icon is always [AppTokens.onTint].
class IconTile extends StatelessWidget {
  const IconTile({
    super.key,
    required this.color,
    this.icon,
    this.child,
    this.size = 42,
    this.radius = AppTokens.radiusTile,
    this.iconSize,
    this.outline,
  }) : assert(icon != null || child != null);

  final Color color;
  final IconData? icon;

  /// Drawn in place of [icon] (the "?" of an uncategorised row, for instance).
  final Widget? child;
  final double size;
  final double radius;
  final double? iconSize;

  /// Outline colour; [AppTokens.line] when null. Pass ink for a tile on a gold card, where the line colour of
  /// dark mode (paper) would vanish against the white tile.
  final Color? outline;

  @override
  Widget build(BuildContext context) {
    final ink = AppTokens.onTint.resolveFrom(context);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: outline ?? AppTokens.line.resolveFrom(context),
          width: AppTokens.outlineThin,
        ),
      ),
      child: IconTheme.merge(
        data: IconThemeData(color: ink, size: iconSize ?? size / 2),
        child: DefaultTextStyle.merge(
          style: TextStyle(color: ink, decoration: TextDecoration.none),
          child: child ?? Icon(icon),
        ),
      ),
    );
  }
}
