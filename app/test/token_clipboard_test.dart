import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

void main() {
  testWidgets('the copied token leaves the clipboard after a minute', (
    tester,
  ) async {
    String? clip;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clip = (call.arguments as Map)['text'] as String?;
        }
        if (call.method == 'Clipboard.getData') return {'text': clip};
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final h = Harness(signedIn: true);
    await tester.pumpWidget(await h.build());
    await tester.pumpAndSettle();
    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ingest token'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CupertinoButton, 'Create new token'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CupertinoButton, 'Copy'));
    await tester.pump();
    expect(clip, 'stk_TESTTOKEN');

    await tester.pump(const Duration(seconds: 30));
    expect(clip, 'stk_TESTTOKEN');
    await tester.pump(const Duration(seconds: 31));
    await tester.pump();
    expect(clip, '');
  });

  testWidgets('something else the owner copied is never wiped', (tester) async {
    String? clip;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clip = (call.arguments as Map)['text'] as String?;
        }
        if (call.method == 'Clipboard.getData') return {'text': clip};
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final h = Harness(signedIn: true);
    await tester.pumpWidget(await h.build());
    await tester.pumpAndSettle();
    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ingest token'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CupertinoButton, 'Create new token'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CupertinoButton, 'Copy'));
    await tester.pump();
    clip = 'my shopping list';
    await tester.pump(const Duration(seconds: 61));
    await tester.pump();
    expect(clip, 'my shopping list');
  });
}
