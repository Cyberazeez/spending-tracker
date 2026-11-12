import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:spending_tracker/core/models.dart';
import 'package:spending_tracker/features/transactions/widgets/txn_row.dart';
import 'package:spending_tracker/l10n/app_localizations.dart';
import 'package:spending_tracker/ui/app_form.dart';
import 'package:spending_tracker/ui/category_sheet.dart';
import 'package:spending_tracker/ui/icon_tile.dart';
import 'package:spending_tracker/ui/swipe_action.dart';
import 'package:spending_tracker/ui/tokens.dart';

import 'support/fakes.dart';

const _ink = Color(0xFF0D1F17);

Widget _app(Widget child, {Brightness brightness = Brightness.light}) =>
    CupertinoApp(
      theme: CupertinoThemeData(brightness: brightness),
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
      ],
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(390, 800),
          platformBrightness: brightness,
        ),
        child: CupertinoPageScaffold(child: Center(child: child)),
      ),
    );

int? _v(Color? c) => c?.toARGB32();

double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

BoxDecoration _tileDecoration(WidgetTester t, Finder tile) =>
    t
            .widget<Container>(
              find.descendant(of: tile, matching: find.byType(Container)).first,
            )
            .decoration!
        as BoxDecoration;

Txn _txn({String? categoryId}) => Txn(
  id: 't1',
  type: 'purchase',
  direction: 'out',
  amountHalalas: 1800,
  occurredAt: DateTime.utc(2026, 10, 30, 9),
  merchant: 'Coffee',
  categoryId: categoryId,
);

void main() {
  for (final b in Brightness.values) {
    testWidgets('IconTile: 2 pt line outline and an ink icon (${b.name})', (
      t,
    ) async {
      await t.pumpWidget(
        _app(
          const IconTile(color: Color(0xFFFFC93C), icon: LucideIcons.coffee),
          brightness: b,
        ),
      );
      final d = _tileDecoration(t, find.byType(IconTile));
      final border = d.border! as Border;
      expect(border.top.width, AppTokens.outlineThin);
      expect(
        _v(border.top.color),
        _v(b == Brightness.dark ? const Color(0xFFF0F5E6) : _ink),
      );
      final icon = t.widget<Icon>(find.byIcon(LucideIcons.coffee));
      final color =
          icon.color ??
          IconTheme.of(t.element(find.byIcon(LucideIcons.coffee))).color;
      expect(_v(color), _v(_ink));
    });

    testWidgets(
      'SecondaryButton(danger) draws its label in danger (${b.name})',
      (t) async {
        await t.pumpWidget(
          _app(
            SizedBox(
              width: 300,
              child: SecondaryButton(
                label: 'Remove',
                danger: true,
                onPressed: () {},
              ),
            ),
            brightness: b,
          ),
        );
        final text = t.widget<Text>(find.text('Remove'));
        expect(
          _v(text.style!.color),
          _v(
            b == Brightness.dark
                ? const Color(0xFFFF9DB0)
                : const Color(0xFFD11A3F),
          ),
        );
      },
    );
  }

  test(
    'swipe Delete label reads at least 4.5:1 on the danger fill in both modes',
    () {
      for (final fill in [const Color(0xFFD11A3F), const Color(0xFFFF9DB0)]) {
        expect(
          _contrast(swipeLabelColor(fill), fill),
          greaterThanOrEqualTo(4.5),
        );
      }
    },
  );

  testWidgets('an uncategorised row has a gold tile with an ink "?"', (
    t,
  ) async {
    await t.pumpWidget(
      _app(
        SizedBox(
          width: 360,
          child: TxnRow(
            txn: _txn(),
            arabic: false,
            category: null,
            onTap: () {},
          ),
        ),
      ),
    );
    final tile = find.byType(IconTile);
    expect(tile, findsOneWidget);
    expect(_v(_tileDecoration(t, tile).color), 0xFFFFC93C);
    expect(find.descendant(of: tile, matching: find.text('?')), findsOneWidget);
    expect(find.textContaining('Choose category'), findsOneWidget);
  });

  testWidgets('a categorised row has the group tile', (t) async {
    await t.pumpWidget(
      _app(
        SizedBox(
          width: 360,
          child: TxnRow(
            txn: _txn(categoryId: 'g'),
            arabic: false,
            category: const Category(id: 'g', name: 'Groceries'),
            onTap: () {},
          ),
        ),
      ),
    );
    expect(find.byIcon(LucideIcons.shoppingCart), findsOneWidget);
    expect(find.text('?'), findsNothing);
  });

  testWidgets(
    'category picker: the chosen tile has a ring and a check; remove returns ""',
    (t) async {
      t.view.physicalSize = const Size(780, 1688);
      t.view.devicePixelRatio = 2;
      addTearDown(t.view.reset);
      final results = <String?>[];
      await t.pumpWidget(
        _app(
          Builder(
            builder: (context) => CupertinoButton(
              child: const Text('open'),
              onPressed: () async => results.add(
                await showCategorySheet(
                  context,
                  cats: const [
                    Category(id: 'g', name: 'Groceries'),
                    Category(id: 'c', name: 'Coffee'),
                  ],
                  arabic: false,
                  selectedId: 'c',
                  removeLabel: 'Remove category',
                ),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('open'));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('category-selected')), findsOneWidget);
      expect(find.byIcon(LucideIcons.check), findsOneWidget);
      await t.tap(find.text('Remove category'));
      await t.pumpAndSettle();
      expect(results, ['']);
    },
  );

  testWidgets(
    'Activity: "No category" chip is gold, the chosen chip is emerald',
    (t) async {
      final h = Harness(signedIn: true);
      h.data.txns = [_txn()];
      await t.pumpWidget(await h.build());
      await t.pumpAndSettle();
      await t.tap(find.text('Activity').last);
      await t.pumpAndSettle();

      Color? fillOf(String label) => t
          .widgetList<DecoratedBox>(
            find.ancestor(
              of: find.text(label),
              matching: find.byType(DecoratedBox),
            ),
          )
          .map((d) => d.decoration)
          .whereType<BoxDecoration>()
          .firstWhere((d) => d.border != null)
          .color;

      expect(_v(fillOf('No category')), 0xFFFFC93C);
      expect(_v(fillOf('All')), 0xFF00A86B);
      await t.tap(find.text('No category'));
      await t.pumpAndSettle();
      expect(_v(fillOf('No category')), 0xFF00A86B);
    },
  );
}
