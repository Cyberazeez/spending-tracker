import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../l10n/app_localizations.dart';
import 'category_groups.dart';

/// One color and one icon per group, so a group is never told apart by color alone.
Color groupColor(CategoryGroup g) => switch (g) {
  CategoryGroup.food => const Color(0xFFFFC93C),
  CategoryGroup.transport => const Color(0xFF9CC4FF),
  CategoryGroup.homeBills => const Color(0xFFFFA574),
  CategoryGroup.family => const Color(0xFF9BE7E0),
  CategoryGroup.horse => const Color(0xFFDDE3CC),
  CategoryGroup.lifestyle => const Color(0xFFCDB4FF),
  CategoryGroup.subscriptions => const Color(0xFFCDB4FF),
  CategoryGroup.health => const Color(0xFFFF9DB0),
  CategoryGroup.money => const Color(0xFF3FD79B),
  CategoryGroup.other => const Color(0xFFDDE3CC),
};

IconData groupIcon(CategoryGroup g) => switch (g) {
  CategoryGroup.food => LucideIcons.utensils,
  CategoryGroup.transport => LucideIcons.car,
  CategoryGroup.homeBills => LucideIcons.house,
  CategoryGroup.family => LucideIcons.users,
  CategoryGroup.horse => LucideIcons.wheat,
  CategoryGroup.lifestyle => LucideIcons.shoppingBag,
  CategoryGroup.subscriptions => LucideIcons.refreshCw,
  CategoryGroup.health => LucideIcons.heartPulse,
  CategoryGroup.money => LucideIcons.landmark,
  CategoryGroup.other => LucideIcons.ellipsis,
};

String groupLabel(AppLocalizations t, CategoryGroup g) => switch (g) {
  CategoryGroup.food => t.groupFood,
  CategoryGroup.transport => t.groupTransport,
  CategoryGroup.homeBills => t.groupHomeBills,
  CategoryGroup.family => t.groupFamily,
  CategoryGroup.horse => t.groupHorse,
  CategoryGroup.lifestyle => t.groupLifestyle,
  CategoryGroup.subscriptions => t.groupSubscriptions,
  CategoryGroup.health => t.groupHealth,
  CategoryGroup.money => t.groupMoney,
  CategoryGroup.other => t.groupOther,
};
