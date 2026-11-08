import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/core/models.dart';

import 'support/fakes.dart';

Future<Harness> openMore(
  WidgetTester tester, {
  bool paid = true,
  bool parseOn = false,
}) async {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final h = Harness(signedIn: true);
  h.data.aiPaid = paid;
  h.data.aiParseOn = parseOn;
  await tester.pumpWidget(await h.build());
  await tester.pumpAndSettle();
  await tester.tap(find.text('More').last);
  await tester.pumpAndSettle();
  return h;
}

AiRead aiRead(String id, {String merchant = 'NEW CAFE', int amount = 4750}) =>
    AiRead(
      raw: RawMessage(
        id: id,
        sender: 'NewBank',
        body: 'Purchase SAR 47.50 at NEW CAFE',
        receivedAt: DateTime.utc(2026, 11, 8, 10),
      ),
      txn: Txn(
        id: 't-$id',
        type: 'purchase',
        direction: 'out',
        amountHalalas: amount,
        occurredAt: DateTime.utc(2026, 11, 8, 10),
        merchant: merchant,
      ),
    );

void main() {
  testWidgets('free accounts do not see the AI reading switch', (tester) async {
    await openMore(tester, paid: false);
    expect(find.text('Read unknown banks with AI'), findsNothing);
  });

  testWidgets('paid accounts see it off, and turning it on asks first', (
    tester,
  ) async {
    final h = await openMore(tester);
    expect(find.text('Read unknown banks with AI'), findsOneWidget);
    expect(h.data.aiParseOn, isFalse);

    final sw = find.byType(CupertinoSwitch);
    // The reading switch is the one after the assistant switch.
    final parse = sw.at(sw.evaluate().length - 3 >= 0 ? 2 : 0);
    await tester.ensureVisible(parse);
    await tester.tap(parse);
    await tester.pumpAndSettle();
    expect(find.text('Let AI read unknown bank messages?'), findsOneWidget);
    // Cancelling changes nothing.
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(h.data.aiParseOn, isFalse);

    await tester.tap(parse);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Turn on'));
    await tester.pumpAndSettle();
    expect(h.data.aiParseOn, isTrue);
  });

  testWidgets('turning it off needs no question', (tester) async {
    final h = await openMore(tester, parseOn: true);
    final sw = find.byType(CupertinoSwitch);
    final parse = sw.at(2);
    await tester.ensureVisible(parse);
    await tester.tap(parse);
    await tester.pumpAndSettle();
    expect(find.text('Let AI read unknown bank messages?'), findsNothing);
    expect(h.data.aiParseOn, isFalse);
  });

  Future<Harness> openReview(WidgetTester tester, List<AiRead> reads) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final h = Harness(signedIn: true);
    h.data.aiRead = reads;
    await tester.pumpWidget(await h.build());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Activity').last);
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('to review'));
    await tester.pumpAndSettle();
    return h;
  }

  testWidgets('AI readings wait for a check and "Looks right" confirms one', (
    tester,
  ) async {
    final h = await openReview(tester, [
      aiRead('r1'),
      aiRead('r2', merchant: 'OTHER'),
    ]);
    expect(find.text('Read by AI: please check'), findsOneWidget);
    expect(find.text('NEW CAFE'), findsOneWidget);
    await tester.tap(find.text('NEW CAFE'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Is it right?'), findsOneWidget);
    await tester.tap(find.text('Looks right'));
    await tester.pumpAndSettle();
    expect(h.data.aiConfirmed, ['r1']);
    expect(find.text('NEW CAFE'), findsNothing);
    expect(find.text('OTHER'), findsOneWidget);
  });

  testWidgets(
    '"Wrong" removes the reading and sends the message back to Needs review',
    (tester) async {
      final h = await openReview(tester, [aiRead('r1')]);
      await tester.tap(find.text('NEW CAFE'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Wrong: remove it'));
      await tester.pumpAndSettle();
      expect(h.data.aiRejected, ['r1']);
      expect(find.text('Read by AI: please check'), findsNothing);
    },
  );

  testWidgets('with nothing to check there is no "to review" badge', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final h = Harness(signedIn: true);
    await tester.pumpWidget(await h.build());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Activity').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('to review'), findsNothing);
  });
}
