import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/core/models.dart';
import 'package:spending_tracker/features/transactions/widgets/filter_chips.dart';

void main() {
  const none = TxFilter();

  test('picking a quick filter turns the other two off', () {
    final noCat = quickFilter(none, QuickFilter.noCategory);
    expect(
      [noCat.uncategorizedOnly, noCat.aiOnly, noCat.hideInternal],
      [true, false, false],
    );
    final ai = quickFilter(noCat, QuickFilter.ai);
    expect(
      [ai.uncategorizedOnly, ai.aiOnly, ai.hideInternal],
      [false, true, false],
    );
    final hide = quickFilter(ai, QuickFilter.hideInternal);
    expect(
      [hide.uncategorizedOnly, hide.aiOnly, hide.hideInternal],
      [false, false, true],
    );
  });

  test('tapping the chosen one again goes back to everything', () {
    for (final chip in QuickFilter.values) {
      final on = quickFilter(none, chip);
      final off = quickFilter(on, chip);
      expect(
        [off.uncategorizedOnly, off.aiOnly, off.hideInternal],
        [false, false, false],
      );
    }
  });

  test('No category drops a chosen category, the others keep it', () {
    const inCategory = TxFilter(categoryId: 'c1');
    expect(quickFilter(inCategory, QuickFilter.noCategory).categoryId, isNull);
    expect(quickFilter(inCategory, QuickFilter.ai).categoryId, 'c1');
    expect(quickFilter(inCategory, QuickFilter.hideInternal).categoryId, 'c1');
  });
}
