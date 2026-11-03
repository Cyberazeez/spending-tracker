import 'package:flutter/cupertino.dart';

import 'tokens.dart';

/// A rounded surface used for every block on the redesigned screens.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTokens.card.resolveFrom(context),
        borderRadius: BorderRadius.circular(AppTokens.radiusCard),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}
