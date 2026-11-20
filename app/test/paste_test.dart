import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:spending_tracker/core/models.dart';
import 'package:spending_tracker/router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import 'support/fakes.dart';

const _sms = 'شراء POS-ApplePay\nبـ SAR 39.00\nبطاقة ائتمانية *8119';

final _purchase = PastePreview(
  kind: 'transaction',
  reader: 'alinma',
  detected: true,
  type: 'purchase',
  direction: 'out',
  bank: 'alinma',
  amountHalalas: 3900,
  merchant: 'MCDONALDS',
  cardLast4: '8119',
  occurredAt: DateTime.utc(2026, 10, 28, 18, 32),
  categoryId: 'c-din',
);

Future<Harness> _open(WidgetTester t, {String path = quickAddPath}) async {
  t.view.physicalSize = const Size(800, 2400);
  t.view.devicePixelRatio = 2;
  addTearDown(t.view.reset);
  final h = Harness(signedIn: true);
  await t.pumpWidget(await h.build());
  await t.pumpAndSettle();
  GoRouter.of(t.element(find.byType(CupertinoPageScaffold).last)).push(path);
  await t.pumpAndSettle();
  return h;
}

Future<void> _readMessage(WidgetTester t, [String text = _sms]) async {
  await t.enterText(find.byKey(const ValueKey('paste-text')), text);
  await t.pump();
  await t.tap(find.byKey(const ValueKey('paste-read')));
  await t.pumpAndSettle();
}

void main() {
  testWidgets(
    'Add a transaction opens Paste; a read purchase is added on Add',
    (t) async {
      final h = await _open(t);
      expect(find.text('Paste a bank message'), findsOneWidget);
      expect(find.text('or enter it yourself'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('paste-entry')));
      await t.pumpAndSettle();
      h.data.pasteResult = _purchase;
      await _readMessage(t);
      expect(h.data.pasteCalls.single, ('preview', _sms, null, false));
      expect(find.text('MCDONALDS'), findsOneWidget);
      expect(find.text('Dining'), findsOneWidget);
      expect(find.text('Found in the text'), findsOneWidget);
      expect(find.textContaining('Alinma Bank ··'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('paste-add')));
      await t.pumpAndSettle();
      expect(h.data.pasteCalls.last, ('commit', _sms, 'alinma', false));
      expect(find.text('Added'), findsOneWidget);
    },
  );

  testWidgets(
    'a purchase already recorded asks first: Keep one saves nothing',
    (t) async {
      final h = await _open(t, path: pastePath);
      h.data.pasteResult = PastePreview(
        kind: 'transaction',
        reader: 'alinma',
        type: 'purchase',
        direction: 'out',
        bank: 'alinma',
        amountHalalas: 3900,
        cardLast4: '8119',
        duplicates: [
          PasteDuplicate(
            id: 't1',
            merchant: 'MCDONALDS',
            amountHalalas: 3900,
            occurredAt: DateTime.utc(2026, 10, 28, 18, 32),
          ),
        ],
      );
      await _readMessage(t);
      expect(find.text('This looks already recorded'), findsOneWidget);
      expect(find.byKey(const ValueKey('paste-add')), findsNothing);
      await t.tap(find.byKey(const ValueKey('paste-keep-one')));
      await t.pumpAndSettle();
      expect(h.data.pasteCalls.where((c) => c.$1 == 'commit'), isEmpty);
      expect(find.byKey(const ValueKey('paste-text')), findsNothing);
    },
  );

  testWidgets('Add anyway saves a purchase that looks recorded', (t) async {
    final h = await _open(t, path: pastePath);
    h.data.pasteResult = PastePreview(
      kind: 'transaction',
      reader: 'alinma',
      type: 'purchase',
      direction: 'out',
      amountHalalas: 3900,
      duplicates: [
        PasteDuplicate(
          id: 't1',
          amountHalalas: 3900,
          occurredAt: DateTime.utc(2026),
        ),
      ],
    );
    await _readMessage(t);
    await t.tap(find.byKey(const ValueKey('paste-add-anyway')));
    await t.pumpAndSettle();
    expect(h.data.pasteCalls.last.$1, 'commit');
  });

  testWidgets('a message not read offers AI only while it is on, and by hand', (
    t,
  ) async {
    final h = await _open(t, path: pastePath);
    h.data.pasteResult = const PastePreview(kind: 'unparsed');
    await _readMessage(t, 'something');
    expect(find.text("This message couldn't be read"), findsOneWidget);
    expect(find.byKey(const ValueKey('paste-ai')), findsNothing);
    expect(find.byKey(const ValueKey('paste-by-hand')), findsOneWidget);

    h.data.pasteResult = const PastePreview(
      kind: 'unparsed',
      aiAvailable: true,
    );
    await t.enterText(
      find.byKey(const ValueKey('paste-text')),
      'something else',
    );
    await t.pump();
    await t.tap(find.byKey(const ValueKey('paste-read')));
    await t.pumpAndSettle();
    h.data.pasteSaved = const PasteResult(outcome: 'review');
    await t.tap(find.byKey(const ValueKey('paste-ai')));
    await t.pumpAndSettle();
    expect(h.data.pasteCalls.last, ('commit', 'something else', null, true));
    expect(
      find.text('Saved. It waits for your check in Activity.'),
      findsOneWidget,
    );
  });

  testWidgets('Enter it by hand opens the manual form', (t) async {
    final h = await _open(t, path: pastePath);
    h.data.pasteResult = const PastePreview(kind: 'unparsed');
    await _readMessage(t, 'something');
    await t.tap(find.byKey(const ValueKey('paste-by-hand')));
    await t.pumpAndSettle();
    expect(find.text('Add a transaction'), findsOneWidget);
  });

  testWidgets('a picked bank is sent with the message', (t) async {
    final h = await _open(t, path: pastePath);
    await t.enterText(find.byKey(const ValueKey('paste-text')), _sms);
    await t.pump();
    await t.tap(find.byKey(const ValueKey('paste-from')));
    await t.pumpAndSettle();
    await t.tap(find.text('Alinma Bank').last);
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('paste-read')));
    await t.pumpAndSettle();
    expect(h.data.pasteCalls.single.$3, 'alinma');
  });

  testWidgets('offline: the error is shown and nothing is lost', (t) async {
    final h = await _open(t, path: pastePath);
    h.data.pasteFails = true;
    await _readMessage(t);
    expect(find.byKey(const ValueKey('paste-error')), findsOneWidget);
    expect(find.byKey(const ValueKey('paste-read')), findsOneWidget);
  });

  testWidgets(
    'Add a bill opens Paste; a bill message for a bill you have updates it',
    (t) async {
      final h = await _open(t, path: addBillPath);
      expect(find.text('Paste a bill message'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('paste-entry')));
      await t.pumpAndSettle();
      h.data.pasteResult = PastePreview(
        kind: 'bill',
        reader: 'se',
        detected: true,
        biller: 'se',
        lineLast4: '4579',
        amountHalalas: 50016,
        issuedAt: DateTime.utc(2026, 11, 20, 9),
        billId: 'ob1',
        billName: 'Electricity',
        billPeriodStart: DateTime.utc(2026, 11),
        billDueDate: DateTime.utc(2026, 12, 20),
      );
      await _readMessage(t, 'electricity bill');
      expect(find.textContaining('Saudi Electricity bill for'), findsOneWidget);
      expect(find.text('Electricity'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('paste-update-bill')));
      await t.pumpAndSettle();
      expect(h.data.pasteCalls.last, (
        'commit',
        'electricity bill',
        'se',
        false,
      ));
      expect(h.data.savedObligations, isEmpty);
    },
  );

  testWidgets(
    'a bill message with no bill creates one with its number, then saves it',
    (t) async {
      final h = await _open(t, path: pasteBillPath);
      h.data.pasteResult = PastePreview(
        kind: 'bill',
        reader: 'stc900',
        biller: 'stc',
        lineLast4: '0569',
        amountHalalas: 27893,
        issuedAt: DateTime.utc(2026, 11, 20, 9),
      );
      await _readMessage(t, 'stc bill');
      expect(find.textContaining('No bill uses'), findsOneWidget);
      expect(find.text('Day 2'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('paste-create-bill')));
      await t.pumpAndSettle();
      final (id, def) = h.data.savedObligations.single;
      expect(id, isNull);
      expect(def.kind, 'bill');
      expect(def.line, '0569');
      expect(def.biller, 'stc');
      expect(def.day, 2);
      expect(def.nextMonth, isTrue);
      expect(def.amountHalalas, 27893);
      expect(def.toRpc()['line'], '0569');
      expect(h.data.pasteCalls.last.$1, 'commit');
    },
  );

  testWidgets('a number another bill uses is explained', (t) async {
    final h = await _open(t, path: pasteBillPath);
    h.data.pasteResult = PastePreview(
      kind: 'bill',
      reader: 'stc900',
      biller: 'stc',
      lineLast4: '0569',
      amountHalalas: 27893,
      issuedAt: DateTime.utc(2026, 11, 20, 9),
    );
    h.data.saveObligationError = const PostgrestException(
      message: 'line in use',
    );
    await _readMessage(t, 'stc bill');
    await t.tap(find.byKey(const ValueKey('paste-create-bill')));
    await t.pumpAndSettle();
    expect(find.text('Another bill already uses this number.'), findsOneWidget);
    expect(h.data.pasteCalls.where((c) => c.$1 == 'commit'), isEmpty);
  });

  test('a bill form save never sends a line, so the bill keeps its own', () {
    const d = ObligationDef(name: 'Mobile', kind: 'bill');
    expect(d.toRpc().containsKey('line'), isFalse);
    expect(d.toRpc().containsKey('next_month'), isFalse);
  });

  final shapes = {
    'purchase': _purchase,
    'new bill': PastePreview(
      kind: 'bill',
      reader: 'se',
      detected: true,
      biller: 'se',
      lineLast4: '4579',
      amountHalalas: 50016,
      issuedAt: DateTime.utc(2026, 11, 20, 9),
    ),
    'unread': const PastePreview(kind: 'unparsed', aiAvailable: true),
  };
  for (final lang in ['en', 'ar']) {
    for (final shape in shapes.entries) {
      testWidgets(
        'Paste survives 2x text on a 360pt phone ($lang, ${shape.key})',
        (t) async {
          final h = Harness(signedIn: true);
          h.data.pasteResult = shape.value;
          t.view.physicalSize = const Size(720, 1280);
          t.view.devicePixelRatio = 2;
          t.platformDispatcher.textScaleFactorTestValue = 2.0;
          addTearDown(() {
            t.view.reset();
            t.platformDispatcher.clearAllTestValues();
          });
          await t.pumpWidget(await h.build(prefs: {'locale': lang}));
          await t.pumpAndSettle();
          GoRouter.of(t.element(find.byType(CupertinoPageScaffold).last))
              .push(pastePath);
          await t.pumpAndSettle();
          await t.enterText(find.byKey(const ValueKey('paste-text')), _sms);
          await t.pump();
          final read = find.byKey(const ValueKey('paste-read'));
          await t.scrollUntilVisible(
            read,
            200,
            scrollable: find.byType(Scrollable).last,
          );
          await t.tap(read);
          await t.pumpAndSettle();
          expect(t.takeException(), isNull);
        },
      );
    }
  }
}
