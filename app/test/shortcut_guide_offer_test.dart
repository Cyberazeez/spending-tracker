import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fakes.dart';

Future<Harness> start(
  WidgetTester t, {
  String last = '',
  bool seen = false,
}) async {
  final h = Harness(signedIn: true);
  h.capture.last = last;
  await t.pumpWidget(
    await h.build(
      offerGuide: !seen,
      prefs: seen ? {'guide.seen.user-1': true} : const {},
    ),
  );
  await t.pumpAndSettle();
  return h;
}

void main() {
  testWidgets('a new account is shown the guide once, with a Skip button', (
    t,
  ) async {
    await start(t);
    expect(find.text('Add the shortcut'), findsOneWidget);
    expect(find.text('Step 1 of 7'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
    // Skip closes it and remembers
    await t.tap(find.text('Skip'));
    await t.pumpAndSettle();
    expect(find.text('Add the shortcut'), findsNothing);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('guide.seen.user-1'), isTrue);
  });

  testWidgets('it is not offered again once seen', (t) async {
    await start(t, seen: true);
    expect(find.text('Add the shortcut'), findsNothing);
  });

  testWidgets('an account that already sends messages is not interrupted', (
    t,
  ) async {
    await start(t, last: '11:20:28 HTTP 200');
    expect(find.text('Add the shortcut'), findsNothing);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('guide.seen.user-1'), isTrue);
  });

  testWidgets('the Skip button only appears on page 1, then it is Back', (
    t,
  ) async {
    await start(t);
    await t.tap(find.text('Next'));
    await t.pumpAndSettle();
    expect(find.text('Skip'), findsNothing);
    expect(find.text('Back'), findsOneWidget);
  });
}
