import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/core/models.dart';
import 'package:spending_tracker/l10n/app_localizations.dart';
import 'package:spending_tracker/ui/category_sheet.dart';

const _cats = [
  Category(id: 'g', name: 'Groceries', nameAr: 'بقالة'),
  Category(id: 'd', name: 'Dining', nameAr: 'مطاعم'),
  Category(id: 'f', name: 'Fuel', nameAr: 'وقود'),
  Category(id: 'u', name: 'Utilities', nameAr: 'خدمات'),
];

Future<List<String?>> _open(
  WidgetTester tester, {
  bool arabic = false,
  String? selected,
  List<String> suggested = const [],
  String? remove,
  double textScale = 1,
}) async {
  tester.view.physicalSize = const Size(720, 1280);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final results = <String?>[];
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
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Builder(
        builder: (context) => CupertinoButton(
          child: const Text('open'),
          onPressed: () async => results.add(
            await showCategorySheet(
              context,
              cats: _cats,
              arabic: arabic,
              selectedId: selected,
              subtitle: 'Starbucks · 24.00',
              suggestedIds: suggested,
              removeLabel: remove,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return results;
}

void main() {
  testWidgets('groups the categories, shows the merchant and picks one', (
    tester,
  ) async {
    final r = await _open(tester, selected: 'd');
    expect(find.text('Category'), findsOneWidget);
    expect(find.text('Starbucks · 24.00'), findsOneWidget);
    expect(find.text('FOOD'), findsOneWidget);
    expect(find.text('TRANSPORT'), findsOneWidget);
    await tester.tap(find.text('Fuel'));
    await tester.pumpAndSettle();
    expect(r, ['f']);
  });

  testWidgets('the current category is marked selected', (tester) async {
    await _open(tester, selected: 'd');
    expect(
      tester.getSemantics(find.text('Dining')).flagsCollection.isSelected,
      isNot(0),
    );
  });

  testWidgets('suggestions come first, and search hides them and filters', (
    tester,
  ) async {
    await _open(tester, suggested: ['g']);
    expect(find.text('SUGGESTED FOR THIS MERCHANT'), findsOneWidget);
    expect(find.text('Groceries'), findsNWidgets(2));
    await tester.enterText(find.byType(CupertinoSearchTextField), 'fue');
    await tester.pumpAndSettle();
    expect(find.text('SUGGESTED FOR THIS MERCHANT'), findsNothing);
    expect(find.text('Fuel'), findsOneWidget);
    expect(find.text('Dining'), findsNothing);
    await tester.enterText(find.byType(CupertinoSearchTextField), 'zzz');
    await tester.pumpAndSettle();
    expect(find.text('No category matches'), findsOneWidget);
  });

  testWidgets('the remove button returns an empty id; X and outside dismiss', (
    tester,
  ) async {
    final r = await _open(tester, remove: 'Remove category');
    await tester.tap(find.text('Remove category'));
    await tester.pumpAndSettle();
    expect(r, ['']);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(r, ['', null]);
  });

  testWidgets('no remove button unless asked for', (tester) async {
    await _open(tester);
    expect(find.text('Remove category'), findsNothing);
  });

  testWidgets('Arabic labels and search by the Arabic name', (tester) async {
    await _open(tester, arabic: true);
    expect(find.text('وقود'), findsOneWidget);
    await tester.enterText(find.byType(CupertinoSearchTextField), 'وقو');
    await tester.pumpAndSettle();
    expect(find.text('وقود'), findsOneWidget);
    expect(find.text('مطاعم'), findsNothing);
  });

  testWidgets('survives 2x text without overflow', (tester) async {
    await _open(tester, selected: 'd', suggested: ['g'], textScale: 2);
    expect(tester.takeException(), isNull);
  });
}
