import 'package:flutter/cupertino.dart';

import '../../../core/format.dart';
import '../../../core/models.dart';
import '../../../core/money.dart';
import '../../../l10n/app_localizations.dart';
import '../../../ui/tokens.dart';
import '../../home/category_groups.dart';
import '../../home/group_style.dart';
import '../labels.dart';

const _orange = Color(0xFFFFB340);

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
      if (txn.isInternal) t.txInternal,
      time.replaceAll(RegExp('[\\u2066\\u2069]'), ''),
    ].join(' · ');
    final income = txn.isIncoming && !txn.isInternal;

    return Semantics(
      container: true,
      button: true,
      onTap: onTap,
      label: '$title, $sub, $sign $amount',
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Opacity(
            opacity: txn.isInternal ? 0.65 : 1,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  _Badge(group: group, uncategorised: uncategorised),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: text,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          sub,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: uncategorised
                                ? AppTokens.warnText.resolveFrom(context)
                                : muted,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Directionality(
                      textDirection: TextDirection.ltr,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '$sign $amount',
                          style: TextStyle(
                            fontFeatures: const [FontFeature.tabularFigures()],
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: income ? const Color(0xFF4CD07A) : text,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.group, required this.uncategorised});
  final CategoryGroup group;
  final bool uncategorised;

  @override
  Widget build(BuildContext context) {
    if (uncategorised) {
      return Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _orange.withValues(alpha: 0.22),
          border: Border.all(color: _orange, width: 1.5),
        ),
        child: const Text(
          '?',
          style: TextStyle(
            color: _orange,
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
      child: Icon(groupIcon(group), size: 22, color: const Color(0xFF0B0F14)),
    );
  }
}
