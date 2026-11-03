import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/core/models.dart';

import 'support/fakes.dart';

ObligationInstance inst({String kind = 'fixed'}) => ObligationInstance(
  id: '1',
  obligationId: 'o-1',
  name: 'Gym',
  kind: kind,
  dueDate: DateTime.utc(2026, 11, 5),
  status: 'pending',
  expectedHalalas: 15000,
);

Future<Harness> openBills(
  WidgetTester tester, {
  List<ObligationInstance> list = const [],
  Map<String, Object> prefs = const {},
}) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final h = Harness(signedIn: true);
  h.data.instances = list;
  await tester.pumpWidget(await h.build(prefs: prefs));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Obligations').last);
  await tester.pumpAndSettle();
  return h;
}

Future<void> openForm(WidgetTester tester) async {
  await tester.tap(find.bySemanticsLabel('Add an obligation'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the + button opens the form and a new obligation is saved', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final h = await openBills(tester);
    await openForm(tester);
    expect(find.text('New obligation'), findsOneWidget);
    await tester.enterText(find.byType(CupertinoTextField).at(0), 'Gym');
    await tester.enterText(find.byType(CupertinoTextField).at(1), '150');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(h.data.savedObligations, hasLength(1));
    final (id, d) = h.data.savedObligations.single;
    expect(id, isNull);
    expect(d.name, 'Gym');
    expect(d.amountHalalas, 15000);
    expect(d.kind, 'fixed');
    expect(d.frequency, 'monthly');
    expect(d.startMonth, isNull);
    expect(find.text('New obligation'), findsNothing); // back on Bills
    handle.dispose();
  });

  testWidgets('a name and an amount are required, nothing is sent', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final h = await openBills(tester);
    await openForm(tester);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Enter a name'), findsOneWidget);
    await tester.enterText(find.byType(CupertinoTextField).at(0), 'Gym');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Enter an amount'), findsOneWidget);
    expect(h.data.savedObligations, isEmpty);
    handle.dispose();
  });

  testWidgets('a bill may leave the amount empty', (tester) async {
    final handle = tester.ensureSemantics();
    final h = await openBills(tester);
    await openForm(tester);
    await tester.enterText(find.byType(CupertinoTextField).at(0), 'Water');
    await tester.tap(find.text('Bill'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(h.data.savedObligations.single.$2.amountHalalas, isNull);
    expect(h.data.savedObligations.single.$2.kind, 'bill');
    handle.dispose();
  });

  testWidgets('quarterly asks for the first due month', (tester) async {
    final handle = tester.ensureSemantics();
    final h = await openBills(tester);
    await openForm(tester);
    expect(find.text('First due month'), findsNothing);
    await tester.tap(find.text('Every 3 months'));
    await tester.pumpAndSettle();
    expect(find.text('First due month'), findsOneWidget);
    await tester.enterText(find.byType(CupertinoTextField).at(0), 'Insurance');
    await tester.enterText(find.byType(CupertinoTextField).at(1), '900');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final d = h.data.savedObligations.single.$2;
    expect(d.frequency, 'quarterly');
    expect(d.startMonth, 10); // the fake clock is 30 Oct 2026
    handle.dispose();
  });

  testWidgets('too many match words are refused', (tester) async {
    final handle = tester.ensureSemantics();
    final h = await openBills(tester);
    await openForm(tester);
    await tester.enterText(find.byType(CupertinoTextField).at(0), 'Gym');
    await tester.enterText(find.byType(CupertinoTextField).at(1), '150');
    await tester.enterText(
      find.byType(CupertinoTextField).at(2),
      'a,b,c,d,e,f',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Up to 5 words'), findsOneWidget);
    expect(h.data.savedObligations, isEmpty);
    handle.dispose();
  });

  testWidgets('a failed save shows the error and stays on the form', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final h = await openBills(tester);
    h.data.failSave = true;
    await openForm(tester);
    await tester.enterText(find.byType(CupertinoTextField).at(0), 'Gym');
    await tester.enterText(find.byType(CupertinoTextField).at(1), '150');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('New obligation'), findsOneWidget);
    expect(find.textContaining('Could not save'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('a name that is already used gets its own message', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final h = await openBills(tester);
    h.data.nameTaken = true;
    await openForm(tester);
    await tester.enterText(find.byType(CupertinoTextField).at(0), 'Gym');
    await tester.enterText(find.byType(CupertinoTextField).at(1), '150');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.textContaining('already have an obligation'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('Edit details opens the form filled in and saves by id', (
    tester,
  ) async {
    final h = await openBills(tester, list: [inst()]);
    h.data.editing = const ObligationDef(
      id: 'o-1',
      name: 'Gym',
      amountHalalas: 15000,
      day: 5,
      merchantWords: ['gym club'],
    );
    await tester.tap(find.text('Gym'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit details'));
    await tester.pumpAndSettle();
    expect(find.text('Edit obligation'), findsOneWidget);
    expect(find.text('Gym'), findsOneWidget);
    expect(find.text('gym club'), findsOneWidget);
    await tester.enterText(find.byType(CupertinoTextField).at(1), '200');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final (id, d) = h.data.savedObligations.single;
    expect(id, 'o-1');
    expect(d.amountHalalas, 20000);
    expect(d.merchantWords, ['gym club']);
  });

  testWidgets('Stop tracking asks first, then stops the obligation', (
    tester,
  ) async {
    final h = await openBills(tester, list: [inst()]);
    await tester.tap(find.text('Gym'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Stop tracking'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Paid history stays'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(h.data.stoppedObligations, isEmpty);
    await tester.tap(find.text('Gym'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Stop tracking'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Stop tracking').last);
    await tester.pumpAndSettle();
    expect(h.data.stoppedObligations, ['o-1']);
  });

  testWidgets('a card statement cannot be edited or stopped', (tester) async {
    await openBills(tester, list: [inst(kind: 'card_statement')]);
    await tester.tap(find.text('Gym'));
    await tester.pumpAndSettle();
    expect(find.text('Edit amount'), findsOneWidget);
    expect(find.text('Edit details'), findsNothing);
    expect(find.text('Stop tracking'), findsNothing);
  });

  for (final lang in ['en', 'ar']) {
    testWidgets('the form survives 2x text on a 360pt phone ($lang)', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final h = Harness(signedIn: true);
      tester.view.physicalSize = const Size(720, 1280);
      tester.view.devicePixelRatio = 2;
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(() {
        tester.view.reset();
        tester.platformDispatcher.clearAllTestValues();
      });
      await tester.pumpWidget(await h.build(prefs: {'locale': lang}));
      await tester.pumpAndSettle();
      await tester.tap(
        find.text(lang == 'en' ? 'Obligations' : 'الالتزامات').last,
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.bySemanticsLabel(
          lang == 'en' ? 'Add an obligation' : 'إضافة التزام',
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final quarterly = find.text(
        lang == 'en' ? 'Every 3 months' : 'كل 3 أشهر',
      );
      await tester.ensureVisible(quarterly);
      await tester.pumpAndSettle();
      await tester.tap(quarterly);
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, -2000));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      handle.dispose();
    });
  }
}
