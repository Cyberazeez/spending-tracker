import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/core/models.dart';
import 'package:spending_tracker/core/widget_bridge.dart';

import 'support/fakes.dart';

// The harness clock is 2026-10-30 12:00 UTC (15:00 Riyadh).
Txn tx(String id, String when, int h) => Txn(
  id: id,
  type: 'purchase',
  direction: 'out',
  amountHalalas: h,
  occurredAt: DateTime.parse('${when}Z'),
  merchant: 'Shop',
  merchantNorm: 'shop',
);

void main() {
  testWidgets('opening the app saves today, month and budget for the widget', (
    tester,
  ) async {
    final h = Harness(signedIn: true)
      ..data.todaySpend = 4500
      ..data.monthlyBudget = 800000
      ..data.history = [tx('1', '2026-10-05T09:00:00', 90000)];
    await tester.pumpWidget(await h.build());
    await tester.pumpAndSettle();
    expect(h.widget.saved, isNotEmpty);
    final s = h.widget.saved.last;
    expect(s.todayHalalas, 4500);
    expect(s.monthHalalas, 90000);
    expect(s.budgetHalalas, 800000);
    expect(s.language, 'en');
  });

  testWidgets('without a monthly budget the widget gets none', (tester) async {
    final h = Harness(signedIn: true)
      ..data.history = [tx('1', '2026-10-05T09:00:00', 90000)];
    await tester.pumpWidget(await h.build());
    await tester.pumpAndSettle();
    expect(h.widget.saved.last.budgetHalalas, isNull);
  });

  test('snapshots with the same numbers are equal', () {
    const a = WidgetSnapshot(
      todayHalalas: 1,
      monthHalalas: 2,
      budgetHalalas: null,
      language: 'en',
    );
    const b = WidgetSnapshot(
      todayHalalas: 1,
      monthHalalas: 2,
      budgetHalalas: null,
      language: 'en',
    );
    expect(a, b);
    expect(a.hashCode, b.hashCode);
  });

  test('the native bridge is off outside iOS', () {
    // Tests run on a non-iOS platform: the provider must hand back the no-op bridge.
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(widgetBridgeProvider), isA<NoopWidgetBridge>());
  });
}
