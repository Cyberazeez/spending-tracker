import 'package:flutter/cupertino.dart';

import 'tokens.dart';
import 'press.dart';

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
    this.badge = 0,
  });

  /// A small count in the corner (e.g. how many filters are on); none when 0.
  final int badge;

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
    pressedOpacity: 1,
    onPressed: onPressed,
    child: Padding(
      padding: const EdgeInsets.only(right: 3, bottom: 4),
      child: Pressable(
        offset: const Offset(3, 4),
        enabled: true,
        builder: (context, depth) => DecoratedBox(
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(radius),
            border: outlineOf(context),
            boxShadow: hardShadowOf(
              context,
              offset: const Offset(3, 4) * (1 - depth),
            ),
          ),
          child: SizedBox(
            width: 40,
            height: 40,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: iconColor,
                  semanticLabel: semanticLabel,
                ),
                if (badge > 0)
                  PositionedDirectional(
                    top: -8,
                    end: -8,
                    child: ExcludeSemantics(
                      child: Container(
                        key: const ValueKey('header-badge'),
                        constraints: const BoxConstraints(minWidth: 20),
                        height: 20,
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppTokens.gold.resolveFrom(context),
                          borderRadius: BorderRadius.circular(10),
                          border: outlineOf(context),
                        ),
                        child: Text(
                          '$badge',
                          style: TextStyle(
                            color: AppTokens.onTint.resolveFrom(context),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
