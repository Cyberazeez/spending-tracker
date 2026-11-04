import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/l10n/app_localizations.dart';
import 'package:spending_tracker/ui/amount_sheet.dart';
import 'package:spending_tracker/ui/choice_sheet.dart';
import 'package:spending_tracker/ui/confirm_sheet.dart';

Future<void> _host(
  WidgetTester tester,
  Future<void> Function(BuildContext) open, {
  bool arabic = false,
  double scale = 1,
}) async {
  tester.view.physicalSize = const Size(720, 1280);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    CupertinoApp(
      locale: Locale(arabic ? 'ar' : 'en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
      ],
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Builder(
        builder: (context) => CupertinoButton(
          child: const Text('open'),
          onPressed: () => open(context),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'amount sheet: quick amount fills the field, Save returns halalas',
    (tester) async {
      int? got;
      await _host(
        tester,
        (c) async => got = await showAmountSheet(
          c,
          title: 'Monthly limit',
          subtitle: 'Dining',
          suggestionsHalalas: [500000, 1500000],
          maxHalalas: 10000000000,
          invalidText: 'Enter an amount',
        ),
      );
      expect(find.text('Monthly limit'), findsOneWidget);
      expect(find.text('Dining'), findsOneWidget);
      await tester.tap(find.text('15,000'));
      await tester.pump();
      expect(
        tester
            .widget<CupertinoTextField>(find.byType(CupertinoTextField))
            .controller!
            .text,
        '15000',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(got, 1500000);
    },
  );

  testWidgets('amount sheet: a bad amount shows the error and stays open', (
    tester,
  ) async {
    int? got = -1;
    await _host(
      tester,
      (c) async => got = await showAmountSheet(
        c,
        title: 'Monthly limit',
        maxHalalas: 10000000000,
        invalidText: 'Enter an amount',
      ),
    );
    await tester.enterText(find.byType(CupertinoTextField), '12,50');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Enter an amount'), findsOneWidget);
    expect(got, -1);
    await tester.enterText(find.byType(CupertinoTextField), '1250.5');
    await tester.pump();
    expect(find.text('Enter an amount'), findsNothing);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(got, 125050);
  });

  testWidgets('amount sheet: an existing limit is filled in', (tester) async {
    await _host(
      tester,
      (c) => showAmountSheet(
        c,
        title: 't',
        initialHalalas: 900000,
        maxHalalas: 10000000000,
        invalidText: 'x',
      ),
    );
    expect(
      tester
          .widget<CupertinoTextField>(find.byType(CupertinoTextField))
          .controller!
          .text,
      '9000',
    );
  });

  testWidgets('choice sheet: marks the current one and returns the pick', (
    tester,
  ) async {
    String? got;
    await _host(
      tester,
      (c) async => got = await showChoiceSheet<String>(
        c,
        title: 'Language',
        options: const [
          ChoiceOption(value: 'en', label: 'English', selected: true),
          ChoiceOption(value: 'ar', label: 'العربية'),
        ],
      ),
    );
    expect(
      tester.getSemantics(find.text('English')).flagsCollection.isSelected,
      isNot(0),
    );
    await tester.tap(find.text('العربية'));
    await tester.pumpAndSettle();
    expect(got, 'ar');
  });

  testWidgets('choice sheet: the close button dismisses with null', (
    tester,
  ) async {
    String? got = 'unset';
    await _host(
      tester,
      (c) async => got = await showChoiceSheet<String>(
        c,
        title: 'x',
        options: const [ChoiceOption(value: 'a', label: 'A')],
      ),
    );
    await tester.tap(find.bySemanticsLabel('Cancel'));
    await tester.pumpAndSettle();
    expect(got, isNull);
  });

  for (final arabic in [false, true]) {
    testWidgets('sheets survive 2x text (${arabic ? 'ar' : 'en'})', (
      tester,
    ) async {
      await _host(
        tester,
        (c) => showAmountSheet(
          c,
          title: 'Monthly limit in a very long title that wraps',
          subtitle: 'A long category name that also wraps around',
          suggestionsHalalas: [300000, 500000, 800000, 1000000, 1500000],
          maxHalalas: 10000000000,
          invalidText: 'Enter an amount',
        ),
        arabic: arabic,
        scale: 2,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'confirm sheet: confirm is true, cancel is false, outside is null',
    (tester) async {
      bool? got;
      await _host(
        tester,
        (c) async => got = await showConfirmSheet(
          c,
          title: 'Remove D360 7705?',
          message: 'This cannot be undone.',
          confirmLabel: 'Remove',
          destructive: true,
        ),
      );
      expect(find.text('Remove D360 7705?'), findsOneWidget);
      expect(find.text('This cannot be undone.'), findsOneWidget);
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();
      expect(got, isTrue);
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel').last);
      await tester.pumpAndSettle();
      expect(got, isFalse);
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(got, isNull);
    },
  );

  testWidgets('notice sheet: one button closes it', (tester) async {
    await _host(
      tester,
      (c) => showNoticeSheet(c, title: 'Could not save', okLabel: 'OK'),
    );
    expect(find.text('Could not save'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('Could not save'), findsNothing);
  });

  testWidgets('confirm sheet survives 2x text in Arabic', (tester) async {
    await _host(
      tester,
      (c) => showConfirmSheet(
        c,
        title: 'هل تريد حذف حسابك؟',
        message: 'سيتم حذف كل شيء نهائيًا بعد ٣٠ يومًا دون إمكانية الاستعادة.',
        confirmLabel: 'احذف كل شيء',
        destructive: true,
      ),
      arabic: true,
      scale: 2,
    );
    expect(tester.takeException(), isNull);
  });
}
