import 'package:flutter/cupertino.dart';

import '../../../ui/trailing_box.dart';

import '../../../core/money.dart';
import '../../../l10n/app_localizations.dart';
import '../../../ui/app_card.dart';
import '../../../ui/tokens.dart';
import '../category_groups.dart';
import '../group_style.dart';

/// "Where it went": a stacked bar of the top groups and one row per group (badge, name, share, amount).
/// [totalHalalas] is the whole month's spend, so the shares are of the month, not of the groups shown.
class ShareBar extends StatelessWidget {
  const ShareBar({
    super.key,
    required this.top,
    required this.totalHalalas,
    required this.arabic,
    this.onSeeAll,
  });

  final List<GroupSpend> top;
  final int totalHalalas;
  final bool arabic;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final text = AppTokens.text.resolveFrom(context);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  t.homeWhereItWent,
                  style: TextStyle(
                    color: text,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (onSeeAll != null)
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(44, 44),
                  onPressed: onSeeAll,
                  child: Text(
                    t.homeSeeAll,
                    style: TextStyle(
                      color: AppTokens.accentText.resolveFrom(context),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: SizedBox(
              height: 14,
              child: Row(
                // stretch: a ColoredBox with no child would otherwise get zero height and the bar would be invisible
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < top.length; i++) ...[
                    if (i > 0) const SizedBox(width: 3),
                    Expanded(
                      flex: top[i].halalas,
                      child: ColoredBox(color: groupColor(top[i].group)),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          for (final g in top)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _GroupRow(
                spend: g,
                percent: totalHalalas <= 0
                    ? 0
                    : (g.halalas * 100 / totalHalalas).round(),
                arabic: arabic,
              ),
            ),
        ],
      ),
    );
  }
}

class _GroupRow extends StatelessWidget {
  const _GroupRow({
    required this.spend,
    required this.percent,
    required this.arabic,
  });
  final GroupSpend spend;
  final int percent;
  final bool arabic;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final text = AppTokens.text.resolveFrom(context);
    final muted = AppTokens.muted.resolveFrom(context);
    final amount = formatSar(spend.halalas, arabic: arabic);
    final label = groupLabel(t, spend.group);
    return Semantics(
      container: true,
      label: '$label, $percent%, $amount',
      child: ExcludeSemantics(
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: groupColor(spend.group),
                borderRadius: BorderRadius.circular(AppTokens.radiusTile),
                border: outlineOf(context, width: AppTokens.outlineThin),
              ),
              child: Icon(
                groupIcon(spend.group),
                size: 20,
                color: const Color(0xFF0B0F14),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: text,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text(
                      '$percent%',
                      style: TextStyle(color: muted, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            TrailingBox(
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    amount,
                    style: TextStyle(
                      color: text,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
