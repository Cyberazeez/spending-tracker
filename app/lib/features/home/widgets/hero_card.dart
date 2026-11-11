import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

import '../../../core/format.dart';
import '../../../core/money.dart';
import '../../../l10n/app_localizations.dart';
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

    Widget chip(String label, String value, {bool amount = false}) =>
        DecoratedBox(
          decoration: BoxDecoration(
            color: white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: ink, width: AppTokens.outlineThin),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: TextStyle(color: ink, fontSize: 12)),
                const SizedBox(height: 2),
                Directionality(
                  textDirection: amount
                      ? TextDirection.ltr
                      : Directionality.of(context),
                  child: Text(
                    value,
                    style: const TextStyle(
                      color: ink,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );

    final label = [
      '${t.homeSpentThisMonth}: ${formatSar(monthHalalas, arabic: arabic)}',
      if (budgetHalalas != null)
        t.homeOfBudget(formatSar(budgetHalalas!, arabic: arabic)),
      if (percent != null) '$percent%',
      if (todayHalalas != null)
        '${t.homeTodayShort}: ${formatSar(todayHalalas!, arabic: arabic)}',
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
              padding: const EdgeInsets.all(22),
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
                              t.homeSpentThisMonth,
                              style: TextStyle(color: ink, fontSize: 14),
                            ),
                            const SizedBox(height: 6),
                            TweenAnimationBuilder<double>(
                              tween: Tween(
                                begin: 0,
                                end: monthHalalas.toDouble(),
                              ),
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
                                      fontFeatures: [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            if (budgetHalalas != null)
                              Text(
                                t.homeOfBudget(
                                  ltrIsolate(
                                    formatSar(budgetHalalas!, arabic: arabic),
                                  ),
                                ),
                                style: TextStyle(color: ink, fontSize: 14),
                              )
                            else
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
                      if (percent != null) ...[
                        const SizedBox(width: 12),
                        _Ring(percent: percent, over: over, animate: animate),
                      ],
                    ],
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      if (todayHalalas != null)
                        chip(
                          t.homeTodayShort,
                          formatSar(todayHalalas!, arabic: arabic),
                          amount: true,
                        ),
                      chip(t.homeVsLastMonth, compare),
                      if (left != null)
                        chip(
                          t.homeLeftToSpend,
                          formatSar(left, arabic: arabic),
                          amount: true,
                        ),
                    ],
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

class _Ring extends StatelessWidget {
  const _Ring({
    required this.percent,
    required this.over,
    required this.animate,
  });
  final int percent;
  final bool over;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final fraction = math.min(percent, 100) / 100;
    return SizedBox(
      width: 84,
      height: 84,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: fraction),
        duration: animate ? const Duration(milliseconds: 700) : Duration.zero,
        curve: Curves.easeOutCubic,
        builder: (_, v, _) => CustomPaint(
          painter: _RingPainter(v, over),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: _ltr(
                  Text(
                    '$percent%',
                    style: const TextStyle(
                      color: Color(0xFF0D1F17),
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.fraction, this.over);
  final double fraction;
  final bool over;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 9.0;
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(stroke / 2 + 4);
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = const Color(0xFFFFFFFF);
    canvas.drawArc(arcRect, 0, math.pi * 2, false, track);
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = over ? const Color(0xFFD11A3F) : const Color(0xFFFFC93C);
    canvas.drawArc(arcRect, -math.pi / 2, math.pi * 2 * fraction, false, arc);
    // Ink edges on both sides of the ring, like every other outlined shape.
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color(0xFF0D1F17);
    canvas.drawArc(arcRect.inflate(stroke / 2), 0, math.pi * 2, false, edge);
    canvas.drawArc(arcRect.deflate(stroke / 2), 0, math.pi * 2, false, edge);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.fraction != fraction || old.over != over;
}
