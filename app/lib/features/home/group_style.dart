import 'package:flutter/widgets.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'category_groups.dart';

/// One color and one icon per group, so a group is never told apart by color alone.
Color groupColor(CategoryGroup g) => switch (g) {
  CategoryGroup.food => const Color(0xFF3CC4A8),
  CategoryGroup.transport => const Color(0xFF6C8CFF),
  CategoryGroup.homeBills => const Color(0xFFFFB340),
  CategoryGroup.horse => const Color(0xFFA97B50),
  CategoryGroup.lifestyle => const Color(0xFFC084FC),
  CategoryGroup.subscriptions => const Color(0xFFF472B6),
  CategoryGroup.health => const Color(0xFFFF6B66),
  CategoryGroup.money => const Color(0xFF94A3B8),
  CategoryGroup.other => const Color(0xFF8B97A5),
};

IconData groupIcon(CategoryGroup g) => switch (g) {
  CategoryGroup.food => PhosphorIconsRegular.forkKnife,
  CategoryGroup.transport => PhosphorIconsRegular.car,
  CategoryGroup.homeBills => PhosphorIconsRegular.houseLine,
  CategoryGroup.horse => PhosphorIconsRegular.horse,
  CategoryGroup.lifestyle => PhosphorIconsRegular.shoppingBag,
  CategoryGroup.subscriptions => PhosphorIconsRegular.arrowsClockwise,
  CategoryGroup.health => PhosphorIconsRegular.heartbeat,
  CategoryGroup.money => PhosphorIconsRegular.bank,
  CategoryGroup.other => PhosphorIconsRegular.dotsThreeOutline,
};
