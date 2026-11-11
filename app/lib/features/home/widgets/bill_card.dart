import 'package:flutter/cupertino.dart';

import '../../../core/format.dart';
import '../../../core/models.dart';
import '../../../core/money.dart';
import '../../../l10n/app_localizations.dart';
import '../../../ui/tokens.dart';

/// One upcoming or overdue bill: a status pill, its name, the amount (with "~" when it is an estimate) and the due date.
class BillCard extends StatelessWidget {
  const BillCard({
    super.key,
    required this.bill,
    required this.today,
    required this.arabic,
    this.onTap,
  });

  final ObligationInstance bill;

  /// The Riyadh calendar date (UTC midnight) used to count the days left.
  final DateTime today;
  final bool arabic;

  /// Opens the Bills tab.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final days = bill.dueDate.difference(today).inDays;
    final overdue = days < 0;
    final soon = !overdue && days <= 7;
    final bg = overdue
        ? AppTokens.danger.resolveFrom(context).withValues(alpha: 0.16)
        : soon
        ? AppTokens.warnBg.resolveFrom(context)
        : AppTokens.okBg.resolveFrom(context);
    final fg = overdue
        ? AppTokens.danger.resolveFrom(context)
        : soon
        ? AppTokens.onTint.resolveFrom(context)
        : AppTokens.okText.resolveFrom(context);
    final pill = overdue
        ? t.obStatusOverdue
        : days == 0
        ? t.homeDueToday
        : days == 1
        ? t.homeDueTomorrow
        : t.homeDueIn(days);
    final text = AppTokens.text.resolveFrom(context);
    final muted = AppTokens.muted.resolveFrom(context);
    final estimate = bill.usualMinHalalas != null;
    final amount = bill.expectedHalalas == null
        ? '—'
        : '${estimate ? '~' : ''}${formatSar(bill.expectedHalalas!, arabic: arabic)}';

    return Semantics(
      container: true,
      button: onTap != null,
      onTap: onTap,
      label:
          '${bill.name}, $pill, $amount, ${t.obDue(formatDay(bill.dueDate))}',
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppTokens.card.resolveFrom(context),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      child: Text(
                        pill,
                        style: TextStyle(
                          color: fg,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    bill.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: text,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        amount,
                        style: TextStyle(
                          color: text,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    t.obDue(formatDay(bill.dueDate)),
                    style: TextStyle(color: muted, fontSize: 12),
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
