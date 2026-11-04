import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/ui/launch_skeleton.dart';

import 'support/fakes.dart';

void main() {
  testWidgets(
    'the login fields are one autofill group (email and password filled together)',
    (tester) async {
      final h = Harness();
      await tester.pumpWidget(await h.build());
      await tester.pumpAndSettle();
      final group = find.byType(AutofillGroup);
      expect(group, findsOneWidget);
      expect(
        find.descendant(of: group, matching: find.byType(CupertinoTextField)),
        findsNWidgets(2),
      );
    },
  );

  testWidgets(
    'the lock screen shows the app skeleton and Unlock, not a blank page',
    (tester) async {
      final h = Harness(signedIn: true)..authenticator.result = false;
      await tester.pumpWidget(await h.build());
      await tester.pumpAndSettle();
      expect(find.byType(LaunchSkeleton), findsOneWidget);
      expect(find.widgetWithText(CupertinoButton, 'Unlock'), findsOneWidget);
    },
  );

  testWidgets('Quick add is in the Activity tab only', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final h = Harness(signedIn: true);
    await tester.pumpWidget(await h.build());
    await tester.pumpAndSettle();
    for (final tab in ['Home', 'Bills', 'Insights', 'More']) {
      await tester.tap(find.text(tab).last);
      await tester.pumpAndSettle();
      expect(find.byIcon(CupertinoIcons.add), findsNothing, reason: tab);
    }
    expect(find.text('Activity'), findsWidgets);
    expect(find.text('Transactions'), findsNothing);
  });
}
