import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:spending_tracker/core/models.dart';
import 'package:spending_tracker/features/obligations/widgets/bills_widgets.dart';
import 'package:spending_tracker/l10n/app_localizations.dart';
import 'package:spending_tracker/ui/confirm_sheet.dart';
import 'package:spending_tracker/ui/outlined_bar.dart';

import 'support/fakes.dart';

const _ink = Color(0xFF0D1F17);

final _spend = Txn(
  id: 't1',
  type: 'purchase',
  direction: 'out',
  amountHalalas: 1800,
  occurredAt: DateTime.utc(2026, 10, 30, 9),
  merchant: 'Coffee',
  categoryId: 'c-din',
);

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
        child: CupertinoPageScaffold(
          child: Center(child: SizedBox(width: 300, child: child)),
        ),
      ),
    );

double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  testWidgets('OutlinedBar fills the width and its fill is the fraction', (
    t,
  ) async {
    await t.pumpWidget(
      _app(
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            OutlinedBar(
              fraction: 0.35,
              fill: Color(0xFF00A86B),
              fillKey: ValueKey('fill'),
            ),
          ],
        ),
      ),
    );
    expect(t.getSize(find.byType(OutlinedBar)).width, 300);
    // Inside the 2 pt outline on each side.
    expect(
      t.getSize(find.byKey(const ValueKey('fill'))).width,
      closeTo((300 - 4) * 0.35, 0.5),
    );
  });

  for (final b in Brightness.values) {
    testWidgets(
      'status pills carry a word, an outline and readable text (${b.name})',
      (t) async {
        await t.pumpWidget(
          _app(
            const Column(
              children: [
                StatusPill(label: 'Overdue', tone: PillTone.danger),
                StatusPill(label: 'Pending', tone: PillTone.warn),
                StatusPill(label: 'Paid', tone: PillTone.ok),
                StatusPill(label: 'Skipped', tone: PillTone.muted),
              ],
            ),
            brightness: b,
          ),
        );
        for (final label in ['Overdue', 'Pending', 'Paid', 'Skipped']) {
          final box = t
              .widgetList<DecoratedBox>(
                find.ancestor(
                  of: find.text(label),
                  matching: find.byType(DecoratedBox),
                ),
              )
              .first;
          final d = box.decoration as BoxDecoration;
          expect(d.border, isNotNull, reason: label);
          final fg = t.widget<Text>(find.text(label)).style!.color!;
          expect(
            _contrast(fg, d.color!),
            greaterThanOrEqualTo(4.5),
            reason: '$label in ${b.name}',
          );
        }
      },
    );
  }

  testWidgets('obligation rows use an outlined kind tile with an ink icon', (
    t,
  ) async {
    await t.pumpWidget(
      _app(
        ObligationRow(
          name: 'Electricity bill',
          detail: '385.00',
          kind: 'bill',
          statusLabel: 'Overdue',
          tone: PillTone.danger,
          onTap: () {},
        ),
        brightness: Brightness.dark,
      ),
    );
    final icon = t.widget<Icon>(find.byIcon(LucideIcons.receipt));
    final color =
        icon.color ??
        IconTheme.of(t.element(find.byIcon(LucideIcons.receipt))).color;
    expect(color!.toARGB32(), _ink.toARGB32());
  });

  for (final b in Brightness.values) {
    testWidgets('AI tips card: ink text on gold, 4.5:1 or more (${b.name})', (
      t,
    ) async {
      t.platformDispatcher.platformBrightnessTestValue = b;
      t.view.physicalSize = const Size(390 * 2, 1600 * 2);
      t.view.devicePixelRatio = 2;
      addTearDown(t.view.reset);
      addTearDown(t.platformDispatcher.clearAllTestValues);
      final h = Harness(signedIn: true);
      h.data
        ..aiOn = true
        ..aiPaid = true
        ..saved = ['Dining is up this month.']
        ..txns = [_spend]
        ..history = [_spend];
      await t.pumpWidget(await h.build());
      await t.pumpAndSettle();
      await t.tap(find.text('Insights').last);
      await t.pumpAndSettle();
      final tip = t.widget<Text>(find.text('Dining is up this month.'));
      expect(tip.style!.color!.toARGB32(), _ink.toARGB32());
      expect(
        _contrast(tip.style!.color!, const Color(0xFFFFC93C)),
        greaterThanOrEqualTo(4.5),
      );
    });

    testWidgets('a destructive confirm button label is readable (${b.name})', (
      t,
    ) async {
      await t.pumpWidget(
        _app(
          Builder(
            builder: (context) => CupertinoButton(
              child: const Text('open'),
              onPressed: () => showConfirmSheet(
                context,
                title: 'Stop?',
                confirmLabel: 'Stop tracking',
                cancelLabel: 'Cancel',
                destructive: true,
              ),
            ),
          ),
          brightness: b,
        ),
      );
      await t.tap(find.text('open'));
      await t.pumpAndSettle();
      final label = t.widget<Text>(find.text('Stop tracking'));
      final fill = b == Brightness.dark
          ? const Color(0xFFFF9DB0)
          : const Color(0xFFD11A3F);
      expect(_contrast(label.style!.color!, fill), greaterThanOrEqualTo(4.5));
    });
  }
}
