import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

import '../../../core/money.dart';
import '../../../l10n/app_localizations.dart';
import '../../../ui/tokens.dart';
import '../../insights/metrics.dart' show budgetPercent;

Widget _ltr(Widget child) =>
    Directionality(textDirection: TextDirection.ltr, child: child);

/// The big gradient card: the month's spend, the budget ring and three small facts.
/// No budget set: the ring and "Left to spend" are replaced by a prompt, never a 0%.
class HeroCard extends StatelessWidget {
  const HeroCard({
    super.key,
    required this.monthHalalas,
    required this.todayHalalas,
    required this.arabic,
    this.budgetHalalas,
    this.lastMonthDiffHalalas,
    this.lastMonthPercent,
  });

  final int monthHalalas;
  final int todayHalalas;
  final int? budgetHalalas;

  /// This month so far minus last month to the same day; null when there is nothing to compare with.
  final int? lastMonthDiffHalalas;

  /// The same difference as a whole percent of last month's figure; null when it cannot be computed.
  final int? lastMonthPercent;
  final bool arabic;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final percent = budgetPercent(monthHalalas, budgetHalalas);
    final over = percent != null && percent >= 100;
    final animate = !MediaQuery.disableAnimationsOf(context);
    const white = Color(0xFFFFFFFF);

    final compare = lastMonthDiffHalalas == null
        ? '—'
        : lastMonthDiffHalalas == 0
        ? t.homeSameShort
        : lastMonthPercent == null
        ? formatSar(lastMonthDiffHalalas!.abs(), arabic: arabic)
        : lastMonthDiffHalalas! < 0
        ? t.homeLower(lastMonthPercent!.abs())
        : t.homeHigher(lastMonthPercent!.abs());

    Widget chip(String label, String value) => DecoratedBox(
      decoration: BoxDecoration(
        color: white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: white.withValues(alpha: 0.9),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 2),
            _ltr(
              Text(
                value,
                style: const TextStyle(
                  color: white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return Semantics(
      container: true,
      label:
          '${t.homeSpentThisMonth}: ${formatSar(monthHalalas, arabic: arabic)}'
          '${percent == null ? '' : ', $percent%'}',
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTokens.radiusHero),
          gradient: LinearGradient(
            begin: AlignmentDirectional.topStart.resolve(
              Directionality.of(context),
            ),
            end: AlignmentDirectional.bottomEnd.resolve(
              Directionality.of(context),
            ),
            colors: [
              AppTokens.heroFrom.resolveFrom(context),
              AppTokens.heroTo.resolveFrom(context),
            ],
          ),
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
                          style: TextStyle(
                            color: white.withValues(alpha: 0.9),
                            fontSize: 14,
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
                                  color: white,
                                  fontSize: 40,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -1,
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        if (budgetHalalas != null)
                          _ltr(
                            Text(
                              t.homeOfBudget(
                                formatSar(budgetHalalas!, arabic: arabic),
                              ),
                              style: TextStyle(
                                color: white.withValues(alpha: 0.9),
                                fontSize: 14,
                              ),
                            ),
                          )
                        else
                          Text(
                            t.homeSetBudget,
                            style: const TextStyle(
                              color: white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
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
                  chip(
                    t.homeTodayShort,
                    formatSar(todayHalalas, arabic: arabic),
                  ),
                  chip(t.homeVsLastMonth, compare),
                  if (budgetHalalas != null)
                    chip(
                      t.homeLeftToSpend,
                      formatSar(
                        math.max(0, budgetHalalas! - monthHalalas),
                        arabic: arabic,
                      ),
                    ),
                ],
              ),
            ],
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
            child: _ltr(
              Text(
                '$percent%',
                style: const TextStyle(
                  color: Color(0xFFFFFFFF),
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
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
      ..color = const Color(0x40FFFFFF);
    canvas.drawArc(arcRect, 0, math.pi * 2, false, track);
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = over ? const Color(0xFFFF8A80) : const Color(0xFFFFFFFF);
    canvas.drawArc(arcRect, -math.pi / 2, math.pi * 2 * fraction, false, arc);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.fraction != fraction || old.over != over;
}
