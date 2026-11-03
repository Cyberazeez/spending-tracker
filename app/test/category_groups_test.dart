import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/core/models.dart';
import 'package:spending_tracker/features/home/category_groups.dart';
import 'package:spending_tracker/features/insights/metrics.dart';

Category cat(String id, String name) => Category(id: id, name: name);

void main() {
  test('every seeded category lands in the group from the spec', () {
    const expected = {
      'Groceries': CategoryGroup.food,
      'Dining': CategoryGroup.food,
      'Fuel': CategoryGroup.transport,
      'Transport': CategoryGroup.transport,
      'Car': CategoryGroup.transport,
      'Utilities': CategoryGroup.homeBills,
      'Rent/Housing': CategoryGroup.homeBills,
      'House Card': CategoryGroup.homeBills,
      'Horse': CategoryGroup.horse,
      'Shopping': CategoryGroup.lifestyle,
      'Entertainment': CategoryGroup.lifestyle,
      'Travel': CategoryGroup.lifestyle,
      'Subscriptions': CategoryGroup.subscriptions,
      'Health': CategoryGroup.health,
      'Loans': CategoryGroup.money,
      'Fees': CategoryGroup.money,
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
