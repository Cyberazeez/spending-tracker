import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../l10n/app_localizations.dart';
import 'category_groups.dart';

/// One color and one icon per group, so a group is never told apart by color alone.
Color groupColor(CategoryGroup g) => switch (g) {
  CategoryGroup.food => const Color(0xFF3CC4A8),
  CategoryGroup.transport => const Color(0xFF6C8CFF),
  CategoryGroup.homeBills => const Color(0xFFFFB340),
  CategoryGroup.family => const Color(0xFF38BDF8),
  CategoryGroup.horse => const Color(0xFFA97B50),
  CategoryGroup.lifestyle => const Color(0xFFC084FC),
  CategoryGroup.subscriptions => const Color(0xFFF472B6),
  CategoryGroup.health => const Color(0xFFFF6B66),
  CategoryGroup.money => const Color(0xFF94A3B8),
  CategoryGroup.other => const Color(0xFF8B97A5),
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
