import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/features/home/home_page.dart';
import 'package:spending_tracker/features/more/more_page.dart';

import 'delete_apple_test.dart' show openDelete;
import 'support/fakes.dart';

Future<Harness> openMore(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final h = Harness(signedIn: true);
  await tester.pumpWidget(await h.build());
  await tester.pumpAndSettle();
  await tester.tap(find.text('More').last);
  await tester.pumpAndSettle();
  return h;
}

Future<void> tapSignOut(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.byKey(const ValueKey('more-sign-out')),
    150,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('more-sign-out')));
}

Future<void> signInAgain(WidgetTester tester) async {
  await tester.enterText(
    find.byType(CupertinoTextField).first,
    'me@example.com',
  );
  await tester.enterText(find.byType(CupertinoTextField).last, 'pw');
  await tester.tap(find.widgetWithText(CupertinoButton, 'Sign in'));
  await tester.pumpAndSettle();
}

void main() {
  group('sign out', () {
    testWidgets('says "Signing out…" at once and cannot be tapped twice', (
      tester,
    ) async {
      final h = await openMore(tester);
      h.auth.signOutGate = Completer<void>();
      await tapSignOut(tester);
      await tester.pump();

      expect(find.text('Signing out…'), findsOneWidget);
      expect(find.byKey(const ValueKey('secondary-busy')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('more-sign-out')));
      await tester.pump();
      expect(h.auth.signOutCalls, 1);

      h.auth.signOutGate!.complete();
      await tester.pumpAndSettle();
      expect(find.widgetWithText(CupertinoButton, 'Sign in'), findsOneWidget);
    });

    testWidgets('signing out from More and back in opens on Home, not More', (
      tester,
    ) async {
      await openMore(tester);
      expect(find.byType(MorePage), findsOneWidget);
      await tapSignOut(tester);
      await tester.pumpAndSettle();
      await signInAgain(tester);

      expect(find.byType(HomePage), findsOneWidget);
      expect(find.byType(MorePage), findsNothing);
    });
  });

  group('keyboard', () {
    testWidgets(
      'Cancel on the delete confirmation does not bring the keyboard back',
      (tester) async {
        await openMore(tester);
        await tester.tap(find.text('Your account'));
        await tester.pumpAndSettle();
        await openDelete(tester);

        await tester.enterText(find.byType(CupertinoTextField).at(0), 'DELETE');
        await tester.enterText(find.byType(CupertinoTextField).at(1), 'secret');
        expect(tester.testTextInput.isVisible, isTrue);
        await tester.tap(
          find.widgetWithText(CupertinoButton, 'Delete my account'),
        );
        await tester.pumpAndSettle();
        expect(tester.testTextInput.isVisible, isFalse);

        await tester.tap(find.text('Keep my account'));
        await tester.pumpAndSettle();
        expect(tester.testTextInput.isVisible, isFalse);
      },
    );

    testWidgets('going back from a screen puts the keyboard away', (
      tester,
    ) async {
      await openMore(tester);
      await tester.tap(find.text('Your account'));
      await tester.pumpAndSettle();
      await openDelete(tester);
      await tester.showKeyboard(find.byType(CupertinoTextField).first);
      expect(tester.testTextInput.isVisible, isTrue);

      final nav = tester.state<NavigatorState>(find.byType(Navigator).last);
      nav.pop();
      await tester.pumpAndSettle();
      expect(tester.testTextInput.isVisible, isFalse);
    });

    testWidgets('tapping outside a field puts the keyboard away', (
      tester,
    ) async {
      await openMore(tester);
      await tester.tap(find.text('Your account'));
      await tester.pumpAndSettle();
      await openDelete(tester);
      await tester.showKeyboard(find.byType(CupertinoTextField).first);
      expect(tester.testTextInput.isVisible, isTrue);

      await tester.tapAt(const Offset(200, 1100));
      await tester.pumpAndSettle();
      expect(tester.testTextInput.isVisible, isFalse);
    });
  });
}
