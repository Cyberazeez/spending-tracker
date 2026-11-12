import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/core/banks.dart';
import 'package:spending_tracker/core/models.dart';
import 'package:spending_tracker/features/more/capture_label.dart';

import 'support/fakes.dart';

Future<Harness> _open(WidgetTester tester, Harness h) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(await h.build());
  await tester.pumpAndSettle();
  await tester.tap(find.text('More'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('SMS capture'));
  await tester.pumpAndSettle();
  return h;
}

void main() {
  testWidgets('a good last send shows Working and each bank\'s status', (
    tester,
  ) async {
    final h = Harness(signedIn: true)
      ..capture.hasToken = true
      ..capture.tokenUser = 'user-1'
      ..capture.last = '11:20:05 HTTP 200'
      ..data.gaps = [
        SenderGap(
          sender: 'alinma',
          lastReceivedAt: DateTime.utc(2026, 11, 12, 8),
        ),
        SenderGap(
          sender: 'barq app',
          lastReceivedAt: DateTime.utc(2026, 11, 11, 8),
        ),
      ]
      ..data.accounts = [
        const OwnAccount(
          id: 'a1',
          bank: 'alinma',
          last4: '6000',
          kind: 'current',
        ),
        const OwnAccount(id: 'a2', bank: 'snb', last4: '1111', kind: 'current'),
      ];
    await _open(tester, h);
    expect(find.text('Working'), findsOneWidget);
    expect(find.textContaining('Last sent'), findsOneWidget);
    expect(find.text('Alinma Bank'), findsOneWidget);
    expect(find.text('barq'), findsOneWidget);
    expect(find.text('Saudi National Bank (SNB)'), findsOneWidget);
    expect(find.text('Connected'), findsNWidgets(2));
    expect(find.text('No messages yet'), findsOneWidget);

    await tester.tap(find.text('Open Shortcuts'));
    await tester.pumpAndSettle();
    expect(h.capture.shortcutsOpened, 1);
  });

  testWidgets(
    'offline is not a failure; it counts what waits and sends it now',
    (tester) async {
      final h = Harness(signedIn: true)
        ..capture.hasToken = true
        ..capture.tokenUser = 'user-1'
        ..capture.pending = 2
        ..capture.last = '19:55:13 error -1009';
      await _open(tester, h);
      expect(find.text('No connection'), findsOneWidget);
      expect(find.text('Not sending'), findsNothing);
      expect(find.textContaining('2 waiting'), findsOneWidget);
      final before = h.capture.flushes;
      await tester.tap(find.byKey(const ValueKey('capture-send-now')));
      await tester.pumpAndSettle();
      expect(h.capture.flushes, before + 1);
    },
  );

  testWidgets('nothing sent yet waits for the first message', (tester) async {
    final h = Harness(signedIn: true);
    await _open(tester, h);
    expect(find.text('Waiting for the first message'), findsOneWidget);
    expect(find.text('Show me how, step by step'), findsOneWidget);
  });

  test('the phone\'s log entries are sorted into what they mean', () {
    expect(captureResult(''), CaptureResult.none);
    expect(captureResult('11:20:05 HTTP 200'), CaptureResult.sent);
    expect(captureResult('11:20:05 HTTP 401'), CaptureResult.failed);
    expect(captureResult('19:55:13 error -1009'), CaptureResult.offline);
    expect(captureResult('19:55:13 no response'), CaptureResult.offline);
    expect(captureResult('19:55:13 queued'), CaptureResult.queued);
    expect(captureResult('19:55:13 no token'), CaptureResult.noToken);
  });

  testWidgets('a server refusal is the only pink card', (tester) async {
    final h = Harness(signedIn: true)
      ..capture.hasToken = true
      ..capture.tokenUser = 'user-1'
      ..capture.last = '08:00:01 HTTP 500';
    await _open(tester, h);
    expect(find.text('Not sending'), findsOneWidget);
    expect(find.text('Last send failed (500)'), findsOneWidget);
  });

  testWidgets('an interrupted shortcut says it is waiting to send', (
    tester,
  ) async {
    final h = Harness(signedIn: true)
      ..capture.hasToken = true
      ..capture.tokenUser = 'user-1'
      ..capture.pending = 1
      ..capture.last = '08:00:01 queued';
    await _open(tester, h);
    expect(find.text('Waiting to send'), findsOneWidget);
    expect(find.text('Not sending'), findsNothing);
  });

  test('a bank sender spelled differently is still that bank', () {
    expect(bankCodeForSender('RiyadBank'), 'riyad');
    expect(bankCodeForSender('Riyad Bank'), 'riyad');
    expect(bankCodeForSender('SNB-AlAhli'), 'snb');
    expect(bankCodeForSender('900'), isNull);
    expect(bankCodeForSender('Unknown Shop'), isNull);
  });

  for (final lang in ['en', 'ar']) {
    testWidgets('the capture page survives 2x text at 360 wide ($lang)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(720, 1600);
      tester.view.devicePixelRatio = 2;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      final h = Harness(signedIn: true)
        ..capture.hasToken = true
        ..capture.pending = 3
        ..capture.last = '11:20:05 HTTP 200'
        ..data.gaps = [
          SenderGap(
            sender: 'SNB-AlAhli',
            lastReceivedAt: DateTime.utc(2026, 11, 12),
          ),
        ];
      await tester.pumpWidget(await h.build(prefs: {'locale': lang}));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('tab-item-4')));
      await tester.pumpAndSettle();
      final row = find.byKey(const ValueKey('more-capture'));
      await tester.scrollUntilVisible(
        row,
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('capture-status')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
