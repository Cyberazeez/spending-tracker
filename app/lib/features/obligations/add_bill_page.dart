import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../l10n/app_localizations.dart';
import '../../router.dart';
import '../../ui/app_card.dart';
import '../../ui/app_form.dart';
import '../../ui/icon_tile.dart';
import '../../ui/tokens.dart';
import 'widgets/bills_widgets.dart' show kindStyle;

/// "Add a bill": four starting points (bill, fixed cost, loan, card statement) as tiles, and "Start from scratch".
/// Each opens the bill form with the kind set; everything can be changed there.
class AddBillPage extends StatelessWidget {
  const AddBillPage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final text = AppTokens.text.resolveFrom(context);
    final muted = AppTokens.muted.resolveFrom(context);

    void open(String kind, {String? name}) => context.push(
      Uri(
        path: obligationFormPath,
        queryParameters: {'kind': kind, 'name': ?name},
      ).toString(),
    );

    Widget tile({
      required Key key,
      required String kind,
      required String title,
      required String hint,
      required VoidCallback onTap,
    }) {
      // The mockup's icons for the four starting points; colours as the bill rows.
      final icon = switch (kind) {
        'bill' => LucideIcons.zap,
        'loan' => LucideIcons.car,
        _ => LucideIcons.house,
      };
      final color = kindStyle(kind).color;
      return Semantics(
        button: true,
        label: '$title, $hint',
        excludeSemantics: true,
        child: GestureDetector(
          key: key,
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: AppCard(
            pressable: true,
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconTile(color: color, icon: icon, size: 48, iconSize: 22),
                const SizedBox(height: 14),
                Text(
                  title,
                  style: TextStyle(
                    color: text,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  hint,
                  style: TextStyle(
                    color: muted,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final tiles = [
      tile(
        key: const ValueKey('add-bill-bill'),
        kind: 'bill',
        title: t.addBillBill,
        hint: t.addBillBillHint,
        onTap: () => open('bill'),
      ),
      tile(
        key: const ValueKey('add-bill-fixed'),
        kind: 'fixed',
        title: t.addBillFixed,
        hint: t.addBillFixedHint,
        onTap: () => open('fixed'),
      ),
      tile(
        key: const ValueKey('add-bill-loan'),
        kind: 'loan',
        title: t.addBillLoan,
        hint: t.addBillLoanHint,
        onTap: () => open('loan'),
      ),
    ];

    return CupertinoPageScaffold(
      backgroundColor: AppTokens.bg.resolveFrom(context),
      navigationBar: appNavBar(context, t.addBillTitle),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 0, 2, 14),
              child: Text(
                t.addBillIntro,
                style: TextStyle(
                  color: muted,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
              ),
            ),
            // Two tiles a row, as tall as the taller of the two; an odd last tile takes the whole row.
            for (var i = 0; i < tiles.length; i += 2) ...[
              if (i + 1 < tiles.length)
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: tiles[i]),
                      const SizedBox(width: 10),
                      Expanded(child: tiles[i + 1]),
                    ],
                  ),
                )
              else
                tiles[i],
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 4),
            SecondaryButton(
              key: const ValueKey('add-bill-scratch'),
              label: t.addBillScratch,
              icon: LucideIcons.plus,
              onPressed: () => context.push(obligationFormPath),
            ),
          ],
        ),
      ),
    );
  }
}
