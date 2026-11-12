import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

import '../../../core/format.dart';
import '../../../core/money.dart';
import '../../../l10n/app_localizations.dart';
import '../../../ui/grow_in.dart';
import '../../../ui/tokens.dart';
import '../../insights/metrics.dart' show budgetPercent;

Widget _ltr(Widget child) =>
    Directionality(textDirection: TextDirection.ltr, child: child);

/// The big emerald card: the month's spend, the budget ring and three small facts.
/// No budget set: the ring and "Left to spend" are replaced by a prompt, never a 0%.
class HeroCard extends StatelessWidget {
  const HeroCard({
    super.key,
    required this.monthHalalas,
    required this.arabic,
    this.todayHalalas,
    this.budgetHalalas,
    this.lastMonthDiffHalalas,
    this.lastMonthPercent,
  });

  final int monthHalalas;

  /// Null while it is loading or failed: the Today chip is hidden rather than showing a made-up zero.
  final int? todayHalalas;
  final int? budgetHalalas;

  /// This month so far minus last month to the same day; null when there is nothing to compare with.
  final int? lastMonthDiffHalalas;

  /// The same difference as a whole percent of last month's figure; null when it cannot be computed.
  final int? lastMonthPercent;
  final bool arabic;

  /// "12% lower" / "12% higher" / "Same" / a signed amount when a percent would mislead (last month tiny or empty).
  String _compareText(AppLocalizations t) {
    final diff = lastMonthDiffHalalas;
    if (diff == null) return '—';
    if (diff == 0) return t.homeSameShort;
    final pct = lastMonthPercent;
    if (pct != null && pct == 0) return t.homeSameShort;
    if (pct == null || pct.abs() > 999) {
      return ltrIsolate(
        '${diff < 0 ? '-' : '+'}${formatSar(diff.abs(), arabic: arabic)}',
      );
    }
    final shown = ltrIsolate('${pct.abs()}%');
    return diff < 0 ? t.homeLower(shown) : t.homeHigher(shown);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final percent = budgetPercent(monthHalalas, budgetHalalas);
    final over = percent != null && percent >= 100;
    final animate = !MediaQuery.disableAnimationsOf(context);
    const white = Color(0xFFFFFFFF);
    // Text on the emerald (light) or mint (dark) fill is ink in both modes.
    const ink = Color(0xFF0D1F17);

    final compare = _compareText(t);
    final left = budgetHalalas == null
        ? null
        : math.max(0, budgetHalalas! - monthHalalas);

    // One fact in the white panel: a small label over a bold value.
    Widget fact(String label, String value, {bool amount = false}) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: ink,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Directionality(
          textDirection: amount
              ? TextDirection.ltr
              : Directionality.of(context),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              value,
              style: const TextStyle(
                color: ink,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
      ],
    );

    // Left to spend (or, without a budget, the comparison with last month) and Today.
    final facts = <Widget>[
      if (left != null)
        fact(t.homeLeftToSpend, formatAmountPlain(left), amount: true)
      else
        fact(t.homeVsLastMonth, compare),
      if (todayHalalas != null)
        fact(t.homeTodayShort, formatAmountPlain(todayHalalas!), amount: true),
    ];

    final label = [
      '${t.homeSpentThisMonth}: ${formatSar(monthHalalas, arabic: arabic)}',
      if (budgetHalalas != null)
        t.homeOfBudget(formatSar(budgetHalalas!, arabic: arabic)),
      if (percent != null) '$percent%',
      if (todayHalalas != null)
        '${t.homeTodayShort}: ${formatSar(todayHalalas!, arabic: arabic)}',
      if (left == null)
        '${t.homeVsLastMonth}: ${compare.replaceAll(RegExp('[\\u2066\\u2069]'), '')}',
      if (left != null)
        '${t.homeLeftToSpend}: ${formatSar(left, arabic: arabic)}',
    ].join(', ');
    return Semantics(
      container: true,
      label: label,
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.only(right: 5, bottom: 6),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTokens.radiusHero),
              color: AppTokens.accent.resolveFrom(context),
              border: outlineOf(context),
              boxShadow: hardShadowOf(context, offset: const Offset(5, 6)),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.homeSpentThisMonth,
                    style: const TextStyle(
                      color: ink,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: monthHalalas.toDouble()),
                    duration: animate
                        ? const Duration(milliseconds: 700)
                        : Duration.zero,
                    curve: Curves.easeOutCubic,
                    builder: (_, v, _) => FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerStart,
                      child: _ltr(
                        Text(
                          formatSar(v.round(), arabic: arabic),
                          style: const TextStyle(
                            color: ink,
                            fontSize: 40,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  DecoratedBox(
                    key: const ValueKey('hero-facts'),
                    decoration: BoxDecoration(
                      color: white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: ink, width: AppTokens.outline),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                      child: IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (var i = 0; i < facts.length; i++) ...[
                              if (i > 0)
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 16),
                                  child: SizedBox(
                                    width: 2,
                                    child: ColoredBox(color: ink),
                                  ),
                                ),
                              Expanded(child: facts[i]),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (percent != null) ...[
                    _BudgetBar(percent: percent, over: over),
                    const SizedBox(height: 8),
                    Text(
                      t.homeBudgetLine(
                        ltrIsolate('$percent'),
                        ltrIsolate(formatSar(budgetHalalas!, arabic: arabic)),
                      ),
                      style: const TextStyle(
                        color: ink,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ] else
                    Text(
                      t.homeSetBudget,
                      style: const TextStyle(
                        color: ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
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

/// The budget bar under the facts: gold share of the budget on a white track (red when over), growing in each time
/// Home comes into view.
class _BudgetBar extends StatelessWidget {
  const _BudgetBar({required this.percent, required this.over});
  final int percent;
  final bool over;

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF0D1F17);
    final share = math.min(percent, 100) / 100;
    return Container(
      key: const ValueKey('budget-bar'),
      // Full width: inside a start-aligned column the track would otherwise shrink to the fill.
      width: double.infinity,
      height: 16,
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ink, width: AppTokens.outlineThin),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: share),
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 600),
          curve: Curves.easeOutCubic,
          builder: (_, f, _) => GrowIn(
            builder: (_, g) => FractionallySizedBox(
              alignment: AlignmentDirectional.centerStart,
              widthFactor: (f * g).clamp(0.0, 1.0),
              heightFactor: 1,
              child: DecoratedBox(
                key: const ValueKey('budget-bar-fill'),
                decoration: BoxDecoration(
                  color: over
                      ? const Color(0xFFD11A3F)
                      : const Color(0xFFFFC93C),
                  border: f * g > 0 && f * g < 1
                      ? const BorderDirectional(
                          end: BorderSide(
                            color: ink,
                            width: AppTokens.outlineThin,
                          ),
                        )
                      : null,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
