import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/core/models.dart';

import 'support/fakes.dart';

ObligationInstance inst(
  String id,
  String name,
  String due, {
  String status = 'pending',
  int expected = 18000,
  String matchState = 'none',
}) => ObligationInstance(
  id: id,
  obligationId: 'o-$id',
  name: name,
  kind: 'fixed',
  dueDate: DateTime.parse('${due}T00:00:00Z'),
  status: status,
  expectedHalalas: expected,
  matchState: matchState,
);

Future<Harness> open(WidgetTester tester, List<ObligationInstance> list) async {
  final h = Harness(signedIn: true);
  h.data.instances = list;
  h.data.monthSpend = 500000;
  // 2026-10-30 12:00 UTC is 15:00 in Riyadh
  await tester.pumpWidget(await h.build());
  await tester.pumpAndSettle();
  await tester.tap(find.text('Obligations').last);
  await tester.pumpAndSettle();
  return h;
}

void main() {
  testWidgets('upcoming lists what is due soon with a committed total', (
    tester,
  ) async {
    final h = await open(tester, [
      inst('1', 'Horse and foal', '2026-11-05'),
      inst('2', 'Murabahah', '2026-11-28', expected: 385833),
      inst('3', 'Old one', '2026-10-01'),
    ]);
    expect(h.data.refreshCalls, greaterThan(0));
    expect(find.text('Horse and foal'), findsOneWidget);
    expect(find.text('Murabahah'), findsOneWidget);
    expect(find.text('Old one'), findsNothing);
    expect(find.text('SAR 4,038.33'), findsOneWidget); // 180.00 + 3,858.33
  });

  testWidgets('overdue and history segments', (tester) async {
    await open(tester, [
      inst('1', 'Old one', '2026-10-01'),
      inst('2', 'Paid one', '2026-10-02', status: 'paid'),
    ]);
    await tester.tap(find.text('Overdue').last);
    await tester.pumpAndSettle();
    expect(find.text('Old one'), findsOneWidget);
    expect(find.text('Paid one'), findsNothing);
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    expect(find.text('Paid one'), findsOneWidget);
  });

  testWidgets('mark paid from the row actions moves it to history', (
    tester,
  ) async {
    final h = await open(tester, [inst('1', 'Horse and foal', '2026-11-05')]);
    await tester.tap(find.text('Horse and foal'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mark as paid'));
    await tester.pumpAndSettle();
    expect(h.data.instanceCalls, ['paid:1']);
    expect(find.text('Nothing due in the next 30 days'), findsOneWidget);
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    expect(find.text('Horse and foal'), findsOneWidget);
  });

  testWidgets('a suggested payment can be confirmed or rejected', (
    tester,
  ) async {
    final h = await open(tester, [
      inst('1', 'Internet', '2026-11-02', matchState: 'suggested'),
    ]);
    expect(
      find.textContaining('Mark "Internet" as paid with this payment?'),
      findsOneWidget,
    );
    await tester.tap(find.text('Not this'));
    await tester.pumpAndSettle();
    expect(h.data.instanceCalls, ['reject:1']);
    expect(find.textContaining('with this payment?'), findsNothing);
  });

  testWidgets('confirming a suggestion marks it paid', (tester) async {
    final h = await open(tester, [
      inst('1', 'Internet', '2026-11-02', matchState: 'suggested'),
    ]);
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(h.data.instanceCalls, ['confirm:1']);
    expect(h.data.instances.first.status, 'paid');
  });

  testWidgets('a failed load shows retry', (tester) async {
    final h = Harness(signedIn: true);
    h.data.failLoad = true;
    await tester.pumpWidget(await h.build());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Obligations').last);
    await tester.pumpAndSettle();
    expect(find.text('Could not load. Pull to retry.'), findsOneWidget);
  });

  testWidgets('arabic labels and RTL amounts', (tester) async {
    final h = Harness(signedIn: true);
    h.data.instances = [inst('1', 'Horse', '2026-11-05')];
    await tester.pumpWidget(await h.build(prefs: {'locale': 'ar'}));
    await tester.pumpAndSettle();
    await tester.tap(find.text('الالتزامات').last);
    await tester.pumpAndSettle();
    expect(find.text('القادمة'), findsOneWidget);
    expect(find.textContaining('المتوقع'), findsOneWidget);
  });
}
