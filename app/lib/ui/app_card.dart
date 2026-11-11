import 'package:flutter/cupertino.dart';

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
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final bool flat;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final box = DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? AppTokens.card.resolveFrom(context),
        borderRadius: BorderRadius.circular(radius),
        border: outlineOf(context),
        boxShadow: flat ? null : hardShadowOf(context),
      ),
      child: Padding(padding: padding, child: child),
    );
    if (flat) return box;
    return Padding(
      padding: const EdgeInsets.only(right: 4, bottom: 5),
      child: box,
    );
  }
}
