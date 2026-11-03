import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../core/money.dart';
import '../../../l10n/app_localizations.dart';
import '../../../ui/app_card.dart';
import '../../../ui/tokens.dart';
import '../../insights/metrics.dart';

/// Seven bars, one per day, today highlighted. Plain widgets rather than a chart library: it keeps every bar a
/// real, labelled element for VoiceOver, mirrors correctly in Arabic and animates with no extra code.
class WeekBars extends StatelessWidget {
  const WeekBars({super.key, required this.days, required this.arabic});

  final List<DaySpend> days;
  final bool arabic;

  static const _maxBarHeight = 96.0;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final maxValue = days.fold<int>(0, (m, d) => math.max(m, d.halalas));
    final total = days.fold<int>(0, (s, d) => s + d.halalas);
    final animate = !MediaQuery.disableAnimationsOf(context);
    final locale = arabic ? 'ar' : 'en';
    final accent = AppTokens.accent.resolveFrom(context);
    final idle = AppTokens.bar.resolveFrom(context);
    final muted = AppTokens.muted.resolveFrom(context);
    final text = AppTokens.text.resolveFrom(context);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  t.homeLast7,
                  style: TextStyle(
                    color: text,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Directionality(
                textDirection: TextDirection.ltr,
                child: Text(
                  t.homeWeekTotal(formatSar(total, arabic: arabic)),
                  style: TextStyle(color: muted, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < days.length; i++)
                Expanded(
                  child: Builder(
                    builder: (context) {
                      final d = days[i];
                      final isToday = i == days.length - 1;
                      final weekday = DateFormat('EEEE', locale).format(d.day);
                      final short = DateFormat('E', locale).format(d.day);
                      final h = maxValue == 0
                          ? 4.0
                          : math.max(4.0, d.halalas / maxValue * _maxBarHeight);
                      return Semantics(
                        container: true,
                        label: t.homeBarLabel(
                          formatSar(d.halalas, arabic: arabic),
                          weekday,
                        ),
                        child: ExcludeSemantics(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                height: _maxBarHeight,
                                child: Align(
                                  alignment: Alignment.bottomCenter,
                                  child: TweenAnimationBuilder<double>(
                                    tween: Tween(begin: 0, end: h),
                                    duration: animate
                                        ? const Duration(milliseconds: 500)
                                        : Duration.zero,
                                    curve: Curves.easeOutCubic,
                                    builder: (_, v, _) => Container(
                                      width: 30,
                                      height: v,
                                      decoration: BoxDecoration(
                                        color: isToday ? accent : idle,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                short.characters.first,
                                style: TextStyle(
                                  color: isToday ? text : muted,
                                  fontSize: 12,
                                  fontWeight: isToday
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
    );
  }
}
