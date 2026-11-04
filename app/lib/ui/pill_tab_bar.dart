import 'package:flutter/cupertino.dart';

import 'tokens.dart';

/// The floating, fully rounded tab bar of the design: inset 12 from the sides, a 64 high pill with a soft shadow.
/// Drop-in for [CupertinoTabBar] inside a [CupertinoTabScaffold] (the scaffold clones it with the current index).
class PillTabBar extends CupertinoTabBar {
  const PillTabBar({
    super.key,
    required super.items,
    super.onTap,
    super.currentIndex,
  }) : super(height: _slot, backgroundColor: const Color(0x00000000));

  /// 64 for the pill plus the gap below it and a little air above.
  static const _slot = 80.0;

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
    final accent = AppTokens.accent.resolveFrom(context);
    final muted = AppTokens.muted.resolveFrom(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(12, 0, 12, safe > 24 ? safe - 14 : 16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppTokens.tab.resolveFrom(context),
          borderRadius: BorderRadius.circular(32),
          boxShadow: const [
            BoxShadow(
              color: Color(0x66000000),
              blurRadius: 30,
              spreadRadius: -10,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: SizedBox(
          height: 64,
          child: Row(
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
                      child: IconTheme(
                        data: IconThemeData(
                          size: 24,
                          color: i == currentIndex ? accent : muted,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            items[i].icon,
                            const SizedBox(height: 3),
                            Text(
                              items[i].label ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: i == currentIndex
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: i == currentIndex ? accent : muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
