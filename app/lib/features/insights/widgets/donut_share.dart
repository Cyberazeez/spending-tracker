import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

import '../../../core/money.dart';
import '../../../l10n/app_localizations.dart';
import '../../../ui/app_card.dart';
import '../../../ui/tokens.dart';
import '../../home/category_groups.dart';
import '../../home/group_style.dart';

/// "Where it goes": a ring split by category group, the month's total in the middle, and a legend with the shares.
/// [totalHalalas] is the whole month's spend, so the shares are of the month.
class DonutShare extends StatelessWidget {
  const DonutShare({
    super.key,
    required this.groups,
    required this.totalHalalas,
    required this.arabic,
  });

  final List<GroupSpend> groups;
  final int totalHalalas;
  final bool arabic;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final text = AppTokens.text.resolveFrom(context);
    final muted = AppTokens.muted.resolveFrom(context);
    final stacked = MediaQuery.textScalerOf(context).scale(10) > 13;
    int pct(GroupSpend g) =>
        totalHalalas <= 0 ? 0 : (g.halalas * 100 / totalHalalas).round();

    final ring = Semantics(
      container: true,
      label: '${t.insWhereTitle}: ${formatSar(totalHalalas, arabic: arabic)}',
      excludeSemantics: true,
      child: SizedBox(
        width: 140,
        height: 140,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: const Size(140, 140),
              painter: _DonutPainter(
                [for (final g in groups) (groupColor(g.group), g.halalas)],
                AppTokens.bar.resolveFrom(context),
                AppTokens.line.resolveFrom(context),
              ),
            ),
            // The label box fits inside the ring's inner outline (radius about 44 on the 140 pt donut).
            Padding(
              padding: const EdgeInsets.all(40),
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        riyalSign,
                        style: TextStyle(color: muted, fontSize: 12),
                      ),
                      Text(
                        NumberFormatCompat.whole(totalHalalas),
                        style: TextStyle(
                          color: text,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    final legend = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final g in groups)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Semantics(
              container: true,
              label:
                  '${groupLabel(t, g.group)}, ${pct(g)}%, ${formatSar(g.halalas, arabic: arabic)}',
              child: ExcludeSemantics(
                child: Row(
                  children: [
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: groupColor(g.group),
                        borderRadius: BorderRadius.circular(5),
                        border: outlineOf(
                          context,
                          width: AppTokens.outlineThin,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        groupLabel(t, g.group),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: text,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text(
                        '${pct(g)}%',
                        style: TextStyle(color: muted, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.insWhereTitle,
            style: TextStyle(
              color: text,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          if (stacked) ...[
            Center(child: ring),
            const SizedBox(height: 12),
            legend,
          ] else
            Row(
              children: [
                ring,
                const SizedBox(width: 18),
                Expanded(child: legend),
              ],
            ),
        ],
      ),
    );
  }
}

/// Whole riyals with thousands separators ("4,812"), shown in the ring's centre.
class NumberFormatCompat {
  static String whole(int halalas) {
    final s = (halalas.abs() ~/ 100).toString();
    final out = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) out.write(',');
      out.write(s[i]);
    }
    return out.toString();
  }
}

/// Slices with an ink outline: an outer and an inner ring and a line between slices (the mockup's look).
class _DonutPainter extends CustomPainter {
  _DonutPainter(this.slices, this.background, this.line);

  final List<(Color, int)> slices;
  final Color background;
  final Color line;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 22.0;
    const outline = 2.5;
    final center = size.center(Offset.zero);
    final mid = (math.min(size.width, size.height) - stroke) / 2 - outline;
    final rect = Rect.fromCircle(center: center, radius: mid);
    final total = slices.fold<int>(0, (s, e) => s + e.$2);
    Paint ring(Color c, double w) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..color = c;
    if (total <= 0) {
      canvas.drawArc(rect, 0, math.pi * 2, false, ring(background, stroke));
    } else {
      var start = -math.pi / 2;
      for (final (color, value) in slices) {
        final sweep = math.pi * 2 * value / total;
        canvas.drawArc(rect, start, sweep, false, ring(color, stroke));
        start += sweep;
      }
      if (slices.where((s) => s.$2 > 0).length > 1) {
        start = -math.pi / 2;
        final sep = Paint()
          ..strokeWidth = outline
          ..color = line;
        for (final (_, value) in slices) {
          final dir = Offset(math.cos(start), math.sin(start));
          canvas.drawLine(
            center + dir * (mid - stroke / 2),
            center + dir * (mid + stroke / 2),
            sep,
          );
          start += math.pi * 2 * value / total;
        }
      }
    }
    canvas.drawCircle(center, mid + stroke / 2, ring(line, outline));
    canvas.drawCircle(center, mid - stroke / 2, ring(line, outline));
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.slices != slices || old.background != background || old.line != line;
}
