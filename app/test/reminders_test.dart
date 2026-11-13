import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:spending_tracker/core/models.dart';
import 'package:spending_tracker/core/reminders.dart';

import 'support/fakes.dart';

// The harness clock is 2026-10-30 12:00 UTC (15:00 Riyadh).
ObligationInstance inst(String id, String name, String due, {int? amount}) =>
    ObligationInstance(
      id: id,
      obligationId: 'o-$id',
      name: name,
      kind: 'bill',
      dueDate: DateTime.parse('${due}T00:00:00Z'),
      status: 'pending',
      expectedHalalas: amount,
    );

Future<Harness> openMore(WidgetTester tester, Harness h) async {
  await tester.pumpWidget(await h.build());
  await tester.pumpAndSettle();
  await tester.tap(find.text('More').last);
  await tester.pumpAndSettle();
  return h;
}

/// The switch inside the More row with [key], scrolled into view.
Future<Finder> moreSwitch(WidgetTester tester, String key) async {
  final row = find.byKey(ValueKey(key), skipOffstage: false);
  await tester.scrollUntilVisible(
    row,
    150,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  return find.descendant(of: row, matching: find.byType(CupertinoSwitch));
}

void main() {
  setUpAll(() => initializeDateFormatting('en'));

  test('reminder wording: amount when known, English and Arabic', () {
    final now = DateTime.utc(2026, 10, 30, 12);
    final list = [
      inst('a', 'Mobile', '2026-11-05', amount: 27893),
      inst('b', 'Card statement', '2026-11-06'),
    ];
    final en = reminderItems(list, now, 'en');
    expect(en.map((e) => e.title), ['Mobile', 'Card statement']);
    expect(en[0].body, contains('Due'));
    expect(en[0].body, contains('SAR 278.93'));
    expect(en[1].body, isNot(contains('SAR')));
    // 2 days before the 5th at 09:00 Riyadh = 06:00 UTC on the 3rd
    expect(en[0].at, DateTime.utc(2026, 11, 3, 6));
    final ar = reminderItems(list, now, 'ar');
    expect(ar[0].body, contains('الاستحقاق'));
    expect(ar[0].body, contains('ر.س'));
  });

  testWidgets('turning on bill reminders asks permission and schedules them', (
    tester,
  ) async {
    final h = Harness(signedIn: true)
      ..data.instances = [inst('a', 'Mobile', '2026-11-05', amount: 27893)];
    await openMore(tester, h);
    await tester.tap((await moreSwitch(tester, 'more-reminders')));
    await tester.pumpAndSettle();
    expect(h.reminders.permissionAsks, 1);
    expect(h.reminders.replaced, isNotEmpty);
    expect(h.reminders.replaced.last.single.title, 'Mobile');
    expect(
      tester
          .widget<CupertinoSwitch>((await moreSwitch(tester, 'more-reminders')))
          .value,
      isTrue,
    );
  });

  testWidgets('a refused permission leaves reminders off and explains why', (
    tester,
  ) async {
    final h = Harness(signedIn: true)
      ..data.instances = [inst('a', 'Mobile', '2026-11-05', amount: 27893)];
    h.reminders.grant = false;
    await openMore(tester, h);
    await tester.tap((await moreSwitch(tester, 'more-reminders')));
    await tester.pumpAndSettle();
    expect(find.textContaining('turned off for this app'), findsOneWidget);
    expect(h.reminders.replaced, isEmpty);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<CupertinoSwitch>((await moreSwitch(tester, 'more-reminders')))
          .value,
      isFalse,
    );
  });

  testWidgets('turning reminders off clears the scheduled ones', (
    tester,
  ) async {
    final h = Harness(signedIn: true)
      ..data.instances = [inst('a', 'Mobile', '2026-11-05', amount: 27893)];
    await openMore(tester, h);
    await tester.tap((await moreSwitch(tester, 'more-reminders')));
    await tester.pumpAndSettle();
    await tester.tap((await moreSwitch(tester, 'more-reminders')));
    await tester.pumpAndSettle();
    expect(h.reminders.clears, 1);
    expect(
      tester
          .widget<CupertinoSwitch>((await moreSwitch(tester, 'more-reminders')))
          .value,
      isFalse,
    );
  });

  testWidgets('with reminders off nothing is scheduled', (tester) async {
    final h = Harness(signedIn: true)
      ..data.instances = [inst('a', 'Mobile', '2026-11-05', amount: 27893)];
    await tester.pumpWidget(await h.build());
    await tester.pumpAndSettle();
    expect(h.reminders.replaced, isEmpty);
  });
}
