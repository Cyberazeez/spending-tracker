import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/features/more/shortcut_guide.dart';
import 'package:spending_tracker/l10n/app_localizations.dart';

Future<void> open(
  WidgetTester t, {
  Locale locale = const Locale('en'),
  double textScale = 1,
  Size size = const Size(390, 844),
}) async {
  t.view.physicalSize = size * 3;
  t.view.devicePixelRatio = 3;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    CupertinoApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Builder(
        builder: (context) => CupertinoPageScaffold(
          child: Center(
            child: CupertinoButton(
              onPressed: () => showShortcutGuide(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await t.tap(find.text('open'));
  await t.pumpAndSettle();
}

void main() {
  testWidgets(
    'the guide has seven pages with a snippet each; Next goes through them and Done closes',
    (t) async {
      await open(t);
      expect(find.text('Add the shortcut'), findsOneWidget);
      expect(find.text('Step 1 of 7'), findsOneWidget);
      expect(find.text('Open Automation'), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
      expect(find.text('Back'), findsNothing);
      for (var i = 2; i <= 7; i++) {
        await t.tap(find.byKey(const ValueKey('guide-next')));
        await t.pumpAndSettle();
        expect(find.text('Step $i of 7'), findsOneWidget);
      }
      expect(find.text('All set'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
      await t.tap(find.text('Back'));
      await t.pumpAndSettle();
      expect(find.text('Step 6 of 7'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('guide-next')));
      await t.pumpAndSettle();
      await t.tap(find.text('Done'));
      await t.pumpAndSettle();
      expect(find.text('Add the shortcut'), findsNothing);
    },
  );

  testWidgets('swiping moves between pages', (t) async {
    await open(t);
    await t.drag(
      find.byKey(const ValueKey('guide-pages')),
      const Offset(-300, 0),
    );
    await t.pumpAndSettle();
    expect(find.text('Step 2 of 7'), findsOneWidget);
  });

  testWidgets('Arabic: swiping the other way goes forward', (t) async {
    await open(t, locale: const Locale('ar'));
    expect(find.text('الخطوة 1 من 7'), findsOneWidget);
    await t.drag(
      find.byKey(const ValueKey('guide-pages')),
      const Offset(300, 0),
    );
    await t.pumpAndSettle();
    expect(find.text('الخطوة 2 من 7'), findsOneWidget);
  });

  for (final lang in ['en', 'ar']) {
    testWidgets('survives 2x text on a small phone ($lang)', (t) async {
      await open(
        t,
        locale: Locale(lang),
        textScale: 2,
        size: const Size(360, 640),
      );
      for (var i = 0; i < 6; i++) {
        await t.tap(find.byKey(const ValueKey('guide-next')));
        await t.pumpAndSettle();
      }
      expect(t.takeException(), isNull);
    });
  }
}
