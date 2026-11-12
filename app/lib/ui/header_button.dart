import 'package:flutter/cupertino.dart';

import 'tokens.dart';

/// A 40 pt outlined button with the hard shadow for a title bar, inside a 44 x 44 tap area.
class HeaderIconButton extends StatelessWidget {
  const HeaderIconButton({
    super.key,
    required this.onPressed,
    required this.fill,
    required this.icon,
    required this.iconColor,
    required this.semanticLabel,
    this.radius = 14,
  });

  final VoidCallback onPressed;
  final Color fill;
  final double radius;
  final IconData icon;
  final Color iconColor;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) => CupertinoButton(
    padding: EdgeInsets.zero,
    minimumSize: const Size(44, 44),
    onPressed: onPressed,
    child: Padding(
      padding: const EdgeInsets.only(right: 3, bottom: 4),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(radius),
          border: outlineOf(context),
          boxShadow: hardShadowOf(context, offset: const Offset(3, 4)),
        ),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(
            icon,
            size: 20,
            color: iconColor,
            semanticLabel: semanticLabel,
          ),
        ),
      ),
    ),
  );
}
