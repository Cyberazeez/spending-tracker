import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

void main() {
  testWidgets('More > SMS capture shows the steps, status and opens Shortcuts', (
    tester,
  ) async {
    final h = Harness(signedIn: true)
      ..capture.hasToken = true
      ..capture.tokenUser = 'user-1'
      ..capture.pending = 2
      ..capture.last = '19:55:13 error -1009';
    await tester.pumpWidget(await h.build());
    await tester.pumpAndSettle();
    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SMS capture'));
    await tester.pumpAndSettle();

    expect(find.text('Set up SMS capture'), findsOneWidget);
    expect(find.textContaining('Add bank message'), findsWidgets);
    expect(find.text('2 waiting'), findsOneWidget);
    expect(find.text('19:55:13 error -1009'), findsOneWidget);

    final flushesBefore = h.capture.flushes;
    await tester.tap(find.text('Send waiting messages now'));
    await tester.pumpAndSettle();
    expect(h.capture.flushes, flushesBefore + 1);

    await tester.tap(find.text('Open Shortcuts'));
    await tester.pumpAndSettle();
    expect(h.capture.shortcutsOpened, 1);
  });
}
