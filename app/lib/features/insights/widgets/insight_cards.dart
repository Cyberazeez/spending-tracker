import 'package:flutter/cupertino.dart';

import '../../../ui/trailing_box.dart';
import '../../../ui/chevron.dart';

import '../../../core/format.dart';
import '../../../core/money.dart';
import '../../../l10n/app_localizations.dart';
import '../../../ui/app_card.dart';
import '../../../ui/category_sheet.dart' show categoryIconByName;
import '../../../ui/icon_tile.dart';
import '../../../ui/outlined_bar.dart';
import '../../../ui/tokens.dart';
import '../../home/category_groups.dart';
import '../../home/group_style.dart';
import '../metrics.dart';

Widget _ltr(Widget child) =>
    Directionality(textDirection: TextDirection.ltr, child: child);

TextStyle _title(BuildContext c) => TextStyle(
  color: AppTokens.text.resolveFrom(c),
  fontSize: 17,
  fontWeight: FontWeight.w600,
);

/// "Spent so far", how it compares with the same day last month, the savings rate and the monthly budget bar.
/// Tapping the budget row edits the monthly budget.
class SummaryCard extends StatelessWidget {
  const SummaryCard({
    super.key,
    required this.insights,
    required this.monthlyBudget,
    required this.arabic,
    required this.onBudgetTap,
  });

  final Insights insights;
  final int? monthlyBudget;
  final bool arabic;
  final VoidCallback onBudgetTap;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final text = AppTokens.text.resolveFrom(context);
    final muted = AppTokens.muted.resolveFrom(context);
    final accent = AppTokens.accent.resolveFrom(context);
    String sar(int h) => formatSar(h, arabic: arabic);
    final diff = insights.monthSpend - insights.lastMonthToDate;
    final compare = !insights.lastMonthHasData
        ? t.insNoCompare
        : diff == 0
        ? t.insSame
        : diff > 0
        ? t.insUp(ltrIsolate(sar(diff)))
        : t.insDown(ltrIsolate(sar(-diff)));
    final compareColor = !insights.lastMonthHasData || diff == 0
        ? muted
        : diff > 0
        ? AppTokens.warnText.resolveFrom(context)
        : accent;
    final percent = budgetPercent(insights.monthSpend, monthlyBudget);
    final over = percent != null && percent >= 100;
    final fraction = percent == null ? 0.0 : (percent / 100).clamp(0.0, 1.0);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.insSpent,
                      style: TextStyle(color: muted, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    _ltr(
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          sar(insights.monthSpend),
                          style: TextStyle(
                            color: text,
                            fontSize: 34,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      compare,
                      style: TextStyle(
                        color: compareColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (insights.savingsRate != null) ...[
                const SizedBox(width: 12),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppTokens.bg.resolveFrom(context),
                    borderRadius: BorderRadius.circular(16),
                    border: outlineOf(context, width: AppTokens.outlineThin),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _ltr(
                          Text(
                            t.insSavingsValue(
                              (insights.savingsRate! * 100).round().toString(),
                            ),
                            style: TextStyle(
                              color: AppTokens.accentText.resolveFrom(context),
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
                          t.insSavingsRateLabel,
                          style: TextStyle(color: muted, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          Semantics(
            container: true,
            button: true,
            onTap: onBudgetTap,
            label:
                '${t.insMonthlyBudget}: ${monthlyBudget == null ? t.insMonthlyBudgetNotSet : sar(monthlyBudget!)}'
                '${percent == null ? '' : ', ${t.insMonthlyBudgetUsed(percent.toString())}'}',
            child: ExcludeSemantics(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onBudgetTap,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 44),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              t.insMonthlyBudget,
                              style: TextStyle(
                                color: text,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          TrailingBox(
                            child: monthlyBudget == null
                                ? Text(
                                    t.insMonthlyBudgetNotSet,
                                    style: TextStyle(
                                      color: muted,
                                      fontSize: 13,
                                    ),
                                  )
                                : _ltr(
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        sar(monthlyBudget!),
                                        style: TextStyle(
                                          color: muted,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ),
                          ),
                          const SizedBox(width: 6),
                          ForwardChevron(size: 14, color: muted),
                        ],
                      ),
                      if (monthlyBudget != null) ...[
                        const SizedBox(height: 6),
                        OutlinedBar(
                          fraction: fraction,
                          fill: over
                              ? AppTokens.danger.resolveFrom(context)
                              : accent,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          t.insMonthlyBudgetUsed(percent.toString()),
                          style: TextStyle(color: muted, fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (insights.salaryAboveBase) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  CupertinoIcons.exclamationmark_triangle,
                  size: 16,
                  color: AppTokens.warnText.resolveFrom(context),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    t.insSalaryAbove(sar(insights.baseSalary)),
                    style: TextStyle(color: muted, fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Per category: a colored badge, name, amount and (when set) a budget bar. Tapping a row opens the budget actions.
class CategoryBudgetRow extends StatelessWidget {
  const CategoryBudgetRow({
    super.key,
    required this.name,
    required this.categoryName,
    required this.spent,
    required this.budget,
    required this.arabic,
    required this.onTap,
  });

  final String name;

  /// The English name, used to pick the badge's group.
  final String? categoryName;
  final int spent;
  final int? budget;
  final bool arabic;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final text = AppTokens.text.resolveFrom(context);
    final muted = AppTokens.muted.resolveFrom(context);
    final group = groupOf(categoryName);
    final level = budget == null ? BudgetLevel.ok : budgetLevel(spent, budget!);
    final barColor = switch (level) {
      BudgetLevel.over => AppTokens.danger.resolveFrom(context),
      BudgetLevel.warn => AppTokens.gold.resolveFrom(context),
      BudgetLevel.ok => AppTokens.accent.resolveFrom(context),
    };
    String sar(int h) => formatSar(h, arabic: arabic);
    return Semantics(
      container: true,
      button: onTap != null,
      onTap: onTap,
      label:
          '$name, ${sar(spent)}${budget == null ? '' : ', ${t.insOfLimit(sar(budget!))}'}',
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconTile(
                  color: groupColor(group),
                  icon: categoryIconByName(name),
                  iconSize: 21,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: text,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _AmountBox(
                            sar(spent),
                            style: TextStyle(
                              color: text,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (budget != null) ...[
                        const SizedBox(height: 6),
                        OutlinedBar(
                          fraction: spent / budget!,
                          fill: barColor,
                          height: 10,
                        ),
                        const SizedBox(height: 4),
                        _ltr(
                          Text(
                            t.insOfLimit(sar(budget!)),
                            style: TextStyle(color: muted, fontSize: 12),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A titled card with rows separated by hairlines.
class ListCard extends StatelessWidget {
  const ListCard({
    super.key,
    required this.title,
    required this.children,
    this.footer,
  });

  final String title;
  final List<Widget> children;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final line = AppTokens.bar.resolveFrom(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: _title(context)),
          const SizedBox(height: 6),
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1)
              SizedBox(height: 2, child: ColoredBox(color: line)),
          ],
          ?footer,
        ],
      ),
    );
  }
}

/// One line in a [ListCard]: optional leading widget, title, subtitle and an amount that scales down at large text.
class InsightLine extends StatelessWidget {
  const InsightLine({
    super.key,
    required this.title,
    this.subtitle,
    this.amount,
    this.leading,
  });

  final String title;
  final String? subtitle;
  final String? amount;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final text = AppTokens.text.resolveFrom(context);
    final muted = AppTokens.muted.resolveFrom(context);
    return Semantics(
      container: true,
      label: [title, ?subtitle, ?amount].join(', '),
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 12)],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: text,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: muted, fontSize: 12),
                      ),
                  ],
                ),
              ),
              if (amount != null) ...[
                const SizedBox(width: 8),
                _AmountBox(
                  amount!,
                  style: TextStyle(
                    color: text,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// An amount that keeps its natural width up to about 45% of the row, then scales down, so the name beside it
/// gets all the rest instead of half.
class _AmountBox extends StatelessWidget {
  const _AmountBox(this.amount, {required this.style});
  final String amount;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final maxWidth = MediaQuery.sizeOf(context).width * 0.45;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: _ltr(
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(amount, style: style),
        ),
      ),
    );
  }
}
