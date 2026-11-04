import 'dart:math' as math;

import '../../../ui/trailing_box.dart';

import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../core/money.dart';
import '../../../l10n/app_localizations.dart';
import '../../../ui/app_card.dart';
import '../../../ui/tokens.dart';
import '../metrics.dart';
import 'donut_share.dart' show NumberFormatCompat;

/// The last four months as bars (this month highlighted), with the monthly budget as a dashed line when one is set.
class MonthBars extends StatelessWidget {
  const MonthBars({
    super.key,
    required this.totals,
    required this.arabic,
    this.budgetHalalas,
  });

  final List<MonthTotal> totals;
  final int? budgetHalalas;
  final bool arabic;

  static const _barArea = 110.0;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final text = AppTokens.text.resolveFrom(context);
    final muted = AppTokens.muted.resolveFrom(context);
    final accent = AppTokens.accent.resolveFrom(context);
    final idle = AppTokens.bar.resolveFrom(context);
    final animate = !MediaQuery.disableAnimationsOf(context);
    final maxValue = math.max(
      math.max(1, budgetHalalas ?? 0),
      totals.fold<int>(0, (m, e) => math.max(m, e.halalas)),
    );
    final locale = arabic ? 'ar' : 'en';
    final budgetY = budgetHalalas == null
        ? null
        : _barArea - budgetHalalas! / maxValue * _barArea;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  t.insMonthsTitle,
                  style: TextStyle(
                    color: text,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (budgetHalalas != null)
                TrailingBox(
                  child: Directionality(
                    textDirection: TextDirection.ltr,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        t.insBudgetLine(
                          formatSar(budgetHalalas!, arabic: arabic),
                        ),
                        style: TextStyle(color: muted, fontSize: 13),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Stack(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var i = 0; i < totals.length; i++)
                      Expanded(
                        child: Builder(
                          builder: (context) {
                            final m = totals[i];
                            final isNow = i == totals.length - 1;
                            final month = DateFormat(
                              'MMM',
                              locale,
                            ).format(m.month);
                            final amount = formatSar(m.halalas, arabic: arabic);
                            final h = math.max(
                              m.halalas == 0 ? 3.0 : 6.0,
                              m.halalas / maxValue * _barArea,
                            );
                            return Semantics(
                              container: true,
                              label: t.insMonthBarLabel(month, amount),
                              child: ExcludeSemantics(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        NumberFormatCompat.whole(m.halalas),
                                        style: TextStyle(
                                          color: isNow ? text : muted,
                                          fontSize: 12,
                                          fontWeight: isNow
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    SizedBox(
                                      height: _barArea,
                                      child: Stack(
                                        alignment: Alignment.bottomCenter,
                                        children: [
                                          if (budgetY != null)
                                            Positioned(
                                              left: 0,
                                              right: 0,
                                              top: budgetY.clamp(
                                                0.0,
                                                _barArea - 1,
                                              ),
                                              child: CustomPaint(
                                                size: const Size(
                                                  double.infinity,
                                                  1,
                                                ),
                                                painter: _DashedLine(muted),
                                              ),
                                            ),
                                          TweenAnimationBuilder<double>(
                                            tween: Tween(begin: 0, end: h),
                                            duration: animate
                                                ? const Duration(
                                                    milliseconds: 500,
                                                  )
                                                : Duration.zero,
                                            curve: Curves.easeOutCubic,
                                            builder: (_, v, _) => Container(
                                              width: 44,
                                              height: v,
                                              decoration: BoxDecoration(
                                                color: isNow ? accent : idle,
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      month,
                                      style: TextStyle(
                                        color: isNow ? text : muted,
                                        fontSize: 12,
                                        fontWeight: isNow
                                            ? FontWeight.w700
                                            : FontWeight.w400,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DashedLine extends CustomPainter {
  _DashedLine(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 1.5;
    for (var x = 0.0; x < size.width; x += 9) {
      canvas.drawLine(Offset(x, 0), Offset(math.min(x + 5, size.width), 0), p);
    }
  }

  @override
  bool shouldRepaint(_DashedLine old) => old.color != color;
}
