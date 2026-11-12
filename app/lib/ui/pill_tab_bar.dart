import 'package:flutter/cupertino.dart';

import 'tokens.dart';

/// The floating, fully rounded tab bar of the design: inset 12 from the sides, a 64 high outlined pill with the
/// hard shadow; the selected tab is a wide emerald pill with its icon and name, the others show their icon only.
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
    final bar = AppTokens.tab.resolveFrom(context);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final duration = reduce ? Duration.zero : const Duration(milliseconds: 320);
    return Padding(
      padding: EdgeInsets.fromLTRB(12, 0, 12 - 4, safe > 24 ? safe - 6 : 24),
      child: Padding(
        padding: const EdgeInsets.only(right: 4, bottom: 5),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: bar,
            borderRadius: BorderRadius.circular(32),
            border: outlineOf(context),
            boxShadow: hardShadowOf(context),
          ),
          child: SizedBox(
            height: 64,
            child: LayoutBuilder(
              builder: (context, box) {
                // The selected tab is a wide emerald pill with its icon and name; the others show their icon only.
                // Widths and the pill slide to the tapped tab.
                const pad = 6.0;
                final inner = box.maxWidth - pad * 2;
                final n = items.length;
                final wide = n > 1 ? inner * 0.34 : inner;
                final narrow = n > 1 ? (inner - wide) / (n - 1) : 0.0;
                double width(int i) => i == currentIndex ? wide : narrow;
                double start(int i) {
                  var x = 0.0;
                  for (var j = 0; j < i; j++) {
                    x += width(j);
                  }
                  return x;
                }

                double left(int i) =>
                    pad + (rtl ? inner - start(i) - width(i) : start(i));
                final curve = currentIndex == 0 || currentIndex == n - 1
                    ? Curves.easeOutCubic
                    : const _SmallBack();
                return Stack(
                  children: [
                    AnimatedPositioned(
                      key: const ValueKey('tab-pill'),
                      duration: duration,
                      curve: curve,
                      left: left(currentIndex),
                      width: wide,
                      top: 6,
                      bottom: 6,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppTokens.accent.resolveFrom(context),
                          borderRadius: BorderRadius.circular(26),
                          border: outlineOf(
                            context,
                            width: AppTokens.outlineThin,
                          ),
                        ),
                      ),
                    ),
                    for (var i = 0; i < n; i++)
                      AnimatedPositioned(
                        key: ValueKey('tab-item-$i'),
                        duration: duration,
                        curve: curve,
                        left: left(i),
                        width: width(i),
                        top: 0,
                        bottom: 0,
                        child: _TabItem(
                          item: items[i],
                          selected: i == currentIndex,
                          onTap: () => onTap?.call(i),
                          on: onAccent,
                          off: text,
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.item,
    required this.selected,
    required this.onTap,
    required this.on,
    required this.off,
  });

  final BottomNavigationBarItem item;
  final bool selected;
  final VoidCallback onTap;
  final Color on;
  final Color off;

  @override
  Widget build(BuildContext context) {
    final label = item.label ?? '';
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: IconTheme(
          data: IconThemeData(size: 22, color: selected ? on : off),
          child: Center(
            child: selected
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        item.icon,
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: on,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                // The name stays in the tree, invisible, so the tab is still found by its name.
                : Stack(
                    alignment: Alignment.center,
                    children: [
                      Opacity(
                        opacity: 0,
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.clip,
                          softWrap: false,
                          style: const TextStyle(fontSize: 1),
                        ),
                      ),
                      item.icon,
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
