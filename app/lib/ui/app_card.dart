import 'package:flutter/cupertino.dart';

import 'press.dart';
import 'tokens.dart';

/// The surface of every block: a card with the ink outline and the hard offset shadow.
/// [flat] leaves the shadow out (for a box inside another card). The shadow is kept inside the widget's own
/// box (4 to the right, 5 down), so a scroll view or a sheet that clips at the card's edge cannot cut it off.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.color,
    this.flat = false,
    this.radius = AppTokens.radiusCard,
    this.shadow = const Offset(4, 5),
    this.pressable = false,
  });

  /// For a card that opens something when tapped (the tap handler sits around it): it presses into its shadow
  /// while a finger is on it.
  final bool pressable;

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final bool flat;
  final double radius;

  /// Offset of the hard shadow: (4, 5) on cards, (5, 6) on the big gold and emerald heroes.
  final Offset shadow;

  @override
  Widget build(BuildContext context) {
    Widget box(double depth) => DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? AppTokens.card.resolveFrom(context),
        borderRadius: BorderRadius.circular(radius),
        border: outlineOf(context),
        boxShadow: flat
            ? null
            : hardShadowOf(context, offset: shadow * (1 - depth)),
      ),
      child: Padding(padding: padding, child: child),
    );
    if (flat) return box(0);
    return Padding(
      padding: EdgeInsets.only(right: shadow.dx, bottom: shadow.dy),
      child: pressable
          ? Pressable(offset: shadow, builder: (_, depth) => box(depth))
          : box(0),
    );
  }
}
