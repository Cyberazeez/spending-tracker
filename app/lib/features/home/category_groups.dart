import '../../core/models.dart';
import '../insights/metrics.dart';

/// The categories stay as they are in the database; Home shows them in these few groups so the screen is not a list of 17.
enum CategoryGroup {
  food,
  transport,
  homeBills,
  family,
  horse,
  lifestyle,
  subscriptions,
  health,
  money,
  other,
}

const _groupByCategory = <String, CategoryGroup>{
  'Groceries': CategoryGroup.food,
  'Dining': CategoryGroup.food,
  'Coffee': CategoryGroup.food,
  'Fuel': CategoryGroup.transport,
  'Transport': CategoryGroup.transport,
  'Car': CategoryGroup.transport,
  'Utilities': CategoryGroup.homeBills,
  'Rent/Housing': CategoryGroup.homeBills,
  'House Card': CategoryGroup.homeBills,
  'Education': CategoryGroup.family,
  'Family & Kids': CategoryGroup.family,
  'Horse': CategoryGroup.horse,
  'Shopping': CategoryGroup.lifestyle,
  'Entertainment': CategoryGroup.lifestyle,
  'Travel': CategoryGroup.lifestyle,
  'Hotel': CategoryGroup.lifestyle,
  'Gifts & Charity': CategoryGroup.lifestyle,
  'Pets': CategoryGroup.lifestyle,
  'Subscriptions': CategoryGroup.subscriptions,
  'Health': CategoryGroup.health,
  'Personal care': CategoryGroup.health,
  'Loans': CategoryGroup.money,
  'Fees': CategoryGroup.money,
  'Transfers': CategoryGroup.money,
  'Income': CategoryGroup.money,
  'Insurance': CategoryGroup.money,
  'Government & fees': CategoryGroup.money,
  'Other': CategoryGroup.other,
};

/// Unknown names (a category added later) and no category at all land in [CategoryGroup.other].
CategoryGroup groupOf(String? categoryName) =>
    _groupByCategory[categoryName] ?? CategoryGroup.other;

class GroupSpend {
  const GroupSpend(this.group, this.halalas);
  final CategoryGroup group;
  final int halalas;
}

/// Month spend per group, biggest first. Groups that net to zero or below (refunds) are left out.
List<GroupSpend> groupSpend(
  List<CategorySpend> byCategory,
  List<Category> cats,
) {
  final nameById = {for (final c in cats) c.id: c.name};
  final totals = <CategoryGroup, int>{};
  for (final s in byCategory) {
    final g = groupOf(nameById[s.categoryId]);
    totals[g] = (totals[g] ?? 0) + s.halalas;
  }
  final out = [
    for (final e in totals.entries)
      if (e.value > 0) GroupSpend(e.key, e.value),
  ]..sort((a, b) => b.halalas.compareTo(a.halalas));
  return out;
}
