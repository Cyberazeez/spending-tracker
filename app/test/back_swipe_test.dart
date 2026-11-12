import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

Future<Harness> openMore(WidgetTester tester) async {
  final h = Harness(signedIn: true);
  await tester.pumpWidget(await h.build());
  await tester.pumpAndSettle();
  await tester.tap(find.text('More').last);
  await tester.pumpAndSettle();
  return h;
}

void main() {
  testWidgets('swipe from the left edge goes back from Account', (
    tester,
  ) async {
    await openMore(tester);
    await tester.tap(find.text('Account'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('nav-back')), findsOneWidget);
    await tester.dragFrom(const Offset(3, 300), const Offset(700, 0));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('nav-back')), findsNothing);
    expect(find.text('Sign out'), findsOneWidget);
  });

  testWidgets('swipe goes back two levels, one at a time', (tester) async {
    await openMore(tester);
    await tester.tap(find.text('Account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Security'));
    await tester.pumpAndSettle();
    expect(find.text('Current password'), findsOneWidget);
    await tester.dragFrom(const Offset(3, 300), const Offset(700, 0));
    await tester.pumpAndSettle();
    expect(find.text('Current password'), findsNothing);
    expect(find.text('Profile'), findsOneWidget); // back on Account
    await tester.dragFrom(const Offset(3, 300), const Offset(700, 0));
    await tester.pumpAndSettle();
    expect(find.text('Sign out'), findsOneWidget);
  });

  testWidgets('swipe goes back from SMS capture and the back button too', (
    tester,
  ) async {
    await openMore(tester);
    await tester.tap(find.text('SMS capture'));
    await tester.pumpAndSettle();
    await tester.dragFrom(const Offset(3, 300), const Offset(700, 0));
    await tester.pumpAndSettle();
    expect(find.text('Sign out'), findsOneWidget);
    await tester.tap(find.text('SMS capture'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('nav-back')));
    await tester.pumpAndSettle();
    expect(find.text('Sign out'), findsOneWidget);
  });

  testWidgets('swipe goes back from Quick add and from the obligation form', (
    tester,
  ) async {
    final h = Harness(signedIn: true);
    await tester.pumpWidget(await h.build());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Activity').last);
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Add a transaction'));
    await tester.pumpAndSettle();
    expect(find.text('Add a transaction'), findsWidgets);
    await tester.dragFrom(const Offset(3, 300), const Offset(700, 0));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('nav-back')), findsNothing);
    await tester.tap(find.text('Bills').last);
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Add an obligation'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('add-bill-scratch')));
    await tester.pumpAndSettle();
    expect(find.text('New obligation'), findsOneWidget);
    await tester.dragFrom(const Offset(3, 300), const Offset(700, 0));
    await tester.pumpAndSettle();
    expect(find.text('New obligation'), findsNothing);
  });
}
