import 'package:flutter/cupertino.dart';

import 'tokens.dart';

/// The floating, fully rounded tab bar of the design: inset 12 from the sides, a 64 high outlined pill with the
/// hard shadow; the selected tab is an emerald pill.
/// Drop-in for [CupertinoTabBar] inside a [CupertinoTabScaffold] (the scaffold clones it with the current index).
class PillTabBar extends CupertinoTabBar {
  const PillTabBar({
    super.key,
    required super.items,
    super.onTap,
    super.currentIndex,
  }) : super(height: _slot, backgroundColor: const Color(0x00000000));

  /// 64 for the pill plus the gap below it and a little air above.
  static const _slot = 88.0;

  @override
  bool opaque(BuildContext context) => false;

  @override
  CupertinoTabBar copyWith({
    Key? key,
    List<BottomNavigationBarItem>? items,
    Color? backgroundColor,
    Color? activeColor,
    Color? inactiveColor,
    double? iconSize,
    double? height,
    Border? border,
    int? currentIndex,
    ValueChanged<int>? onTap,
  }) => PillTabBar(
    key: key ?? this.key,
    items: items ?? this.items,
    currentIndex: currentIndex ?? this.currentIndex,
    onTap: onTap ?? this.onTap,
  );

  @override
  Widget build(BuildContext context) {
    final safe = MediaQuery.paddingOf(context).bottom;
    final onAccent = AppTokens.onAccent.resolveFrom(context);
    final text = AppTokens.text.resolveFrom(context);
    final reduce = MediaQuery.disableAnimationsOf(context);
    final pill = Padding(
      padding: const EdgeInsets.all(5),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppTokens.accent.resolveFrom(context),
          borderRadius: BorderRadius.circular(24),
          border: outlineOf(context, width: AppTokens.outlineThin),
        ),
        child: const SizedBox.expand(),
      ),
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(12, 0, 12 - 4, safe > 24 ? safe - 6 : 24),
      child: Padding(
        padding: const EdgeInsets.only(right: 4, bottom: 5),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppTokens.tab.resolveFrom(context),
            borderRadius: BorderRadius.circular(32),
            border: outlineOf(context),
            boxShadow: hardShadowOf(context),
          ),
          child: SizedBox(
            height: 64,
            child: Stack(
              children: [
                // The emerald pill under the selected tab. It slides to the tab that was tapped (with a small
                // overshoot); with Reduce Motion it fades out under the old tab and in under the new one.
                if (reduce)
                  Row(
                    children: [
                      for (var i = 0; i < items.length; i++)
                        Expanded(
                          child: AnimatedOpacity(
                            opacity: i == currentIndex ? 1 : 0,
                            duration: const Duration(milliseconds: 160),
                            child: pill,
                          ),
                        ),
                    ],
                  )
                else if (items.length > 1)
                  AnimatedAlign(
                    key: const ValueKey('tab-pill'),
                    alignment: AlignmentDirectional(
                      -1 + 2 * currentIndex / (items.length - 1),
                      0,
                    ),
                    duration: const Duration(milliseconds: 320),
                    curve: const _SmallBack(),
                    child: FractionallySizedBox(
                      widthFactor: 1 / items.length,
                      heightFactor: 1,
                      child: pill,
                    ),
                  ),
                Row(
                  children: [
                    for (var i = 0; i < items.length; i++)
                      Expanded(
                        child: Semantics(
                          button: true,
                          selected: i == currentIndex,
                          label: items[i].label,
                          excludeSemantics: true,
                          onTap: () => onTap?.call(i),
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => onTap?.call(i),
                            child: Padding(
                              padding: const EdgeInsets.all(5),
                              child: IconTheme(
                                data: IconThemeData(
                                  size: 22,
                                  color: i == currentIndex ? onAccent : text,
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    items[i].icon,
                                    const SizedBox(height: 2),
                                    Text(
                                      items[i].label ?? '',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: i == currentIndex
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        color: i == currentIndex
                                            ? onAccent
                                            : text,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Ease-out with a small overshoot (about 4% of the distance) before it settles: the pill slides a touch past the
/// tab and comes back.
class _SmallBack extends Curve {
  const _SmallBack();

  @override
  double transformInternal(double t) {
    const s = 0.9;
    final u = t - 1;
    return u * u * ((s + 1) * u + s) + 1;
  }
}
