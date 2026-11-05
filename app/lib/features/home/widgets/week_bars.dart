import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../core/format.dart';
import '../../../core/money.dart';
import '../../../l10n/app_localizations.dart';
import '../../../ui/app_card.dart';
import '../../../ui/tokens.dart';
import '../../insights/metrics.dart';

/// Seven bars, one per day, today highlighted. Plain widgets rather than a chart library: it keeps every bar a
/// real, labelled element for VoiceOver, mirrors correctly in Arabic and animates with no extra code.
/// Tap a bar to see what was spent that day: the bar turns green and a bubble with the amount appears above it.
class WeekBars extends StatefulWidget {
  const WeekBars({super.key, required this.days, required this.arabic});

  final List<DaySpend> days;
  final bool arabic;

  @override
  State<WeekBars> createState() => _WeekBarsState();
}

class _WeekBarsState extends State<WeekBars> {
  int? _selected;

  static const _maxBarHeight = 96.0;

  // Monday first (DateTime.weekday is 1 to 7).
  static const _lettersEn = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  static const _lettersAr = ['ن', 'ث', 'ر', 'خ', 'ج', 'س', 'ح'];

  @override
  Widget build(BuildContext context) {
    final days = widget.days;
    final arabic = widget.arabic;
    final t = AppLocalizations.of(context);
    final maxValue = days.fold<int>(0, (m, d) => math.max(m, d.halalas));
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
          Text(
            t.homeLast7,
            style: TextStyle(
              color: text,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          // The amount bubble sits above the tapped bar; the space is kept so the chart does not jump.
          SizedBox(
            height: 40,
            child: AnimatedSwitcher(
              duration: animate
                  ? const Duration(milliseconds: 150)
                  : Duration.zero,
              child: _selected == null
                  ? const SizedBox.shrink(key: ValueKey('no-callout'))
                  : Align(
                      key: ValueKey('callout-$_selected'),
                      alignment: AlignmentDirectional(
                        -1 + 2 * _selected! / (days.length - 1),
                        0,
                      ),
                      child: DecoratedBox(
                        key: const ValueKey('week-bar-callout'),
                        decoration: BoxDecoration(
                          color: accent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                ltrIsolate(
                                  formatSar(
                                    days[_selected!].halalas,
                                    arabic: arabic,
                                  ),
                                ),
                                style: TextStyle(
                                  color: AppTokens.onAccent.resolveFrom(
                                    context,
                                  ),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                DateFormat(
                                  'EEE d MMM',
                                  locale,
                                ).format(days[_selected!].day),
                                style: TextStyle(
                                  color: AppTokens.onAccent
                                      .resolveFrom(context)
                                      .withValues(alpha: 0.85),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < days.length; i++)
                Expanded(
                  child: Builder(
                    builder: (context) {
                      final d = days[i];
                      final isToday = i == days.length - 1;
                      final lit = _selected == null ? isToday : _selected == i;
                      final weekday = DateFormat('EEEE', locale).format(d.day);
                      final letter = (arabic
                          ? _lettersAr
                          : _lettersEn)[d.day.weekday - 1];
                      final h = maxValue == 0
                          ? 4.0
                          : math.max(4.0, d.halalas / maxValue * _maxBarHeight);
                      return Semantics(
                        container: true,
                        button: true,
                        label: t.homeBarLabel(
                          formatSar(d.halalas, arabic: arabic),
                          weekday,
                        ),
                        onTap: () => setState(
                          () => _selected = _selected == i ? null : i,
                        ),
                        child: GestureDetector(
                          key: ValueKey('week-bar-$i'),
                          behavior: HitTestBehavior.opaque,
                          onTap: () => setState(
                            () => _selected = _selected == i ? null : i,
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
                                          color: lit ? accent : idle,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  letter,
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
