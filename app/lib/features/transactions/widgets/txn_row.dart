import 'package:flutter/cupertino.dart';

import '../../../ui/trailing_box.dart';

import '../../../core/format.dart';
import '../../../core/models.dart';
import '../../../core/money.dart';
import '../../../l10n/app_localizations.dart';
import '../../../ui/category_sheet.dart' show categoryIconByName;
import '../../../ui/tokens.dart';
import '../../home/category_groups.dart';
import '../../home/group_style.dart';
import '../labels.dart';

/// One transaction: a round category badge, merchant, "category · time" and the signed amount.
/// Uncategorised rows get an orange "?" badge and say "Choose category"; internal moves are dimmed.
class TxnRow extends StatelessWidget {
  const TxnRow({
    super.key,
    required this.txn,
    required this.arabic,
    required this.category,
    required this.onTap,
  });

  final Txn txn;
  final bool arabic;
  final Category? category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final text = AppTokens.text.resolveFrom(context);
    final muted = AppTokens.muted.resolveFrom(context);
    final amount = formatSar(txn.amountHalalas, arabic: arabic);
    final sign = txn.isIncoming ? '+' : '−';
    final title = (txn.merchant != null && txn.merchant!.isNotEmpty)
        ? txn.merchant!
        : typeLabel(t, txn.type);
    final uncategorised = category == null;
    final group = groupOf(category?.name);
    final time = formatDateTime(txn.occurredAt).split(' ').last;
    final sub = [
      uncategorised ? t.txChooseCategory : category!.label(arabic: arabic),
      if (txn.categorySource == 'ai') t.txAiTag,
      if (txn.isInternal) t.txInternal,
      time.replaceAll(RegExp('[\\u2066\\u2069]'), ''),
    ].join(' · ');
    final income = txn.isIncoming && !txn.isInternal;
    // Past 1.3x text the amount drops under the title instead of squeezing it, like the old list rows did.
    final stacked = MediaQuery.textScalerOf(context).scale(10) > 13;
    final titleColor = txn.isInternal ? muted : text;
    final amountColor = income
        ? AppTokens.income.resolveFrom(context)
        : titleColor;

    final amountText = Directionality(
      textDirection: TextDirection.ltr,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: AlignmentDirectional.centerEnd,
        child: Text(
          '$sign $amount',
          style: TextStyle(
            fontFeatures: const [FontFeature.tabularFigures()],
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: amountColor,
          ),
        ),
      ),
    );
    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: stacked ? 3 : 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: titleColor,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          sub,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: uncategorised
                ? AppTokens.warnText.resolveFrom(context)
                : muted,
            fontSize: 13,
          ),
        ),
        if (stacked) ...[const SizedBox(height: 4), amountText],
      ],
    );

    return Semantics(
      container: true,
      button: true,
      onTap: onTap,
      label: '$title, $sub, $sign $amount',
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              crossAxisAlignment: stacked
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.center,
              children: [
                Opacity(
                  opacity: txn.isInternal ? 0.6 : 1,
                  child: _Badge(
                    group: group,
                    uncategorised: uncategorised,
                    categoryName: category?.name,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: titleBlock),
                if (!stacked) ...[
                  const SizedBox(width: 8),
                  TrailingBox(child: amountText),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.group,
    required this.uncategorised,
    this.categoryName,
  });
  final CategoryGroup group;
  final String? categoryName;
  final bool uncategorised;

  @override
  Widget build(BuildContext context) {
    if (uncategorised) {
      final orange = AppTokens.warnText.resolveFrom(context);
      return Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: orange.withValues(alpha: 0.18),
          border: Border.all(color: orange, width: 1.5),
        ),
        child: Text(
          '?',
          style: TextStyle(
            color: orange,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: groupColor(group),
      ),
      child: Icon(
        categoryName == null
            ? groupIcon(group)
            : categoryIconByName(categoryName!),
        size: 22,
        color: const Color(0xFF0B0F14),
      ),
    );
  }
}
