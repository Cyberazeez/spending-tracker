import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

import '../../../core/money.dart';
import '../../../l10n/app_localizations.dart';
import '../../../ui/app_card.dart';
import '../../../ui/tokens.dart';

/// Spending added up day by day: this month (solid) against last month (dashed). Drawn left to right in every
/// language (time always runs that way), with the numbers repeated in the legend and the spoken label.
class TrendChart extends StatelessWidget {
  const TrendChart({
    super.key,
    required this.thisMonth,
    required this.lastMonth,
    required this.arabic,
  });

  final List<int> thisMonth;
  final List<int> lastMonth;
  final bool arabic;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final text = AppTokens.text.resolveFrom(context);
    final muted = AppTokens.muted.resolveFrom(context);
    final accent = AppTokens.accent.resolveFrom(context);
    final now = thisMonth.isEmpty ? 0 : thisMonth.last;
    final before = (thisMonth.isEmpty || lastMonth.isEmpty)
        ? 0
        : lastMonth[math.min(thisMonth.length, lastMonth.length) - 1];

    // Nothing spent last month on the same days: drawing last month would only squash this month's line, so only this
    // month is drawn and a short note says why.
    final compare = before > 0;
    final drawnLast = compare ? lastMonth : const <int>[];

    Widget legend(String label, Color c) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: c, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(label, style: TextStyle(color: muted, fontSize: 12)),
        ),
      ],
    );

    return AppCard(
      child: Semantics(
        container: true,
        label: compare
            ? '${t.insTrendTitle}: ${t.insTrendLabel(formatSar(now, arabic: arabic), formatSar(before, arabic: arabic))}'
            : '${t.insTrendTitle}: ${formatSar(now, arabic: arabic)}. ${t.insTrendNoLast}',
        child: ExcludeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t.insTrendTitle,
                style: TextStyle(
                  color: text,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 130,
                width: double.infinity,
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: CustomPaint(
                    painter: _TrendPainter(
                      thisMonth: thisMonth,
                      lastMonth: drawnLast,
                      thisColor: accent,
                      lastColor: muted,
                      gridColor: muted.withValues(alpha: 0.2),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 16,
                runSpacing: 6,
                children: [
                  legend(t.insLegendThis, accent),
                  if (compare) legend(t.insLegendLast, muted),
                ],
              ),
              if (!compare) ...[
                const SizedBox(height: 8),
                Text(
                  t.insTrendNoLast,
                  style: TextStyle(color: muted, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  _TrendPainter({
    required this.thisMonth,
    required this.lastMonth,
    required this.thisColor,
    required this.lastColor,
    required this.gridColor,
  });

  final List<int> thisMonth;
  final List<int> lastMonth;
  final Color thisColor;
  final Color lastColor;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    final days = math.max(math.max(thisMonth.length, lastMonth.length), 2);
    final top = math.max(
      1,
      math.max(
        thisMonth.fold<int>(0, math.max),
        lastMonth.fold<int>(0, math.max),
      ),
    );
    final peak = top * 1.1;
    double x(int i) => size.width * i / (days - 1);
    double y(int v) => size.height - (math.max(0, v) / peak) * size.height;

    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final gy = size.height * i / 3;
      canvas.drawLine(Offset(0, gy), Offset(size.width, gy), grid);
    }

    Path line(List<int> v) {
      final p = Path();
      for (var i = 0; i < v.length; i++) {
        i == 0 ? p.moveTo(x(i), y(v[i])) : p.lineTo(x(i), y(v[i]));
      }
      return p;
    }

    if (lastMonth.isNotEmpty) {
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..color = lastColor;
      final metrics = line(lastMonth).computeMetrics();
      for (final m in metrics) {
        var d = 0.0;
        while (d < m.length) {
          canvas.drawPath(m.extractPath(d, math.min(d + 5, m.length)), paint);
          d += 10;
        }
      }
    }
    if (thisMonth.isNotEmpty) {
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = thisColor;
      canvas.drawPath(line(thisMonth), paint);
      canvas.drawCircle(
        Offset(x(thisMonth.length - 1), y(thisMonth.last)),
        5,
        Paint()..color = thisColor,
      );
    }
  }

  @override
  bool shouldRepaint(_TrendPainter old) =>
      old.thisMonth != thisMonth ||
      old.lastMonth != lastMonth ||
      old.thisColor != thisColor ||
      old.lastColor != lastColor;
}
