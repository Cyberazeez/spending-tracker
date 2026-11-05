import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/core/models.dart';
import 'package:spending_tracker/features/home/category_groups.dart';
import 'package:spending_tracker/features/insights/metrics.dart';
import 'package:spending_tracker/ui/category_sheet.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

Category cat(String id, String name) => Category(id: id, name: name);

void main() {
  test('Coffee has its own cup icon, not the Food group one', () {
    expect(categoryIcon(cat('c', 'Coffee')), LucideIcons.coffee);
    expect(categoryIcon(cat('d', 'Dining')), isNot(LucideIcons.coffee));
    expect(categoryIcon(cat('h', 'Hotel')), LucideIcons.hotel);
    const icons = {
      'Education': LucideIcons.graduationCap,
      'Family & Kids': LucideIcons.baby,
      'Gifts & Charity': LucideIcons.gift,
      'Pets': LucideIcons.pawPrint,
      'Personal care': LucideIcons.scissors,
      'Insurance': LucideIcons.shieldCheck,
      'Government & fees': LucideIcons.landmark,
    };
    icons.forEach((n, i) => expect(categoryIcon(cat('x', n)), i, reason: n));
    expect(categoryIcon(cat('t', 'Transfers')), LucideIcons.arrowLeftRight);
    expect(categoryIcon(cat('i', 'Income')), LucideIcons.banknote);
  });

  test('every seeded category lands in the group from the spec', () {
    const expected = {
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
    expected.forEach(
      (name, group) => expect(groupOf(name), group, reason: name),
    );
  });

  test('unknown or missing categories go to Other', () {
    expect(groupOf('Brand new'), CategoryGroup.other);
    expect(groupOf(null), CategoryGroup.other);
  });

  test('groupSpend sums, drops non-positive totals and sorts by amount', () {
    final cats = [
      cat('1', 'Groceries'),
      cat('2', 'Dining'),
      cat('3', 'Fuel'),
      cat('4', 'Health'),
    ];
    final result = groupSpend(const [
      CategorySpend('1', 900),
      CategorySpend('2', 600),
      CategorySpend('3', 1200),
      CategorySpend('4', 0),
      CategorySpend(null, 500), // uncategorised
      CategorySpend('gone', 100), // a category id we do not know
    ], cats);
    expect(result.map((g) => g.group).toList(), [
      CategoryGroup.food, // 1500
      CategoryGroup.transport, // 1200
      CategoryGroup.other, // 600
    ]);
    expect(result.map((g) => g.halalas).toList(), [1500, 1200, 600]);
  });

  test('a negative group total (refunds) is not listed', () {
    final result = groupSpend(
      const [CategorySpend('1', -300)],
      [cat('1', 'Groceries')],
    );
    expect(result, isEmpty);
  });
}
