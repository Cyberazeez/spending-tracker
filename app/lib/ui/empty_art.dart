import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

import 'halala_logo.dart';
import 'tokens.dart';

/// What an empty state's picture says (owner's pick 2026-11-15, "B1"): the هللة logo with its coin spots empty and
/// gold coins falling toward them, or, for good news, the whole logo with its coins in place.
enum EmptyArtKind {
  /// Nothing has arrived yet: both coins are on their way.
  waiting,

  /// Nothing here for now (no matches, nothing this month, not enough data yet): one coin is on its way.
  partial,

  /// All clear (nothing to review, nothing overdue): the full-colour logo, coins in place.
  done,
}

/// The letters of the "empty" logo: sand in light mode, the dark track colour in dark mode.
const emptyArtFill = CupertinoDynamicColor.withBrightness(
  color: Color(0xFFDDE3CC),
  darkColor: Color(0xFF2B4C3D),
);

/// The picture above an empty state's title. Decorative: the title says the same thing, so VoiceOver skips it.
/// The falling coins drop in once when it appears; with Reduce Motion they are drawn at rest.
class EmptyArt extends StatefulWidget {
  const EmptyArt({
    super.key,
    this.kind = EmptyArtKind.waiting,
    this.width = 150,
  });

  final EmptyArtKind kind;
  final double width;

  /// How long the coins take to fall in.
  static const fallDuration = Duration(milliseconds: 900);

  @override
  State<EmptyArt> createState() => _EmptyArtState();
}

class _EmptyArtState extends State<EmptyArt>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fall = AnimationController(
    vsync: this,
    duration: EmptyArt.fallDuration,
    value: 1, // at rest unless the fall plays
  );
  bool _played = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_played &&
        widget.kind != EmptyArtKind.done &&
        !MediaQuery.disableAnimationsOf(context)) {
      _played = true;
      _fall.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _fall.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.kind == EmptyArtKind.done) {
      return ExcludeSemantics(
        child: HalalaLogo(width: widget.width, dropCoins: true),
      );
    }
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _fall,
        builder: (context, _) => CustomPaint(
          size: Size(
            widget.width,
            widget.width * EmptyArtPainter.viewH / EmptyArtPainter.viewW,
          ),
          painter: EmptyArtPainter(
            line: AppTokens.line.resolveFrom(context),
            fill: emptyArtFill.resolveFrom(context),
            spot: AppTokens.bg.resolveFrom(context),
            coin: AppTokens.gold.resolveFrom(context),
            falling: widget.kind == EmptyArtKind.waiting ? 2 : 1,
            progress: Curves.easeOutCubic.transform(_fall.value),
          ),
        ),
      ),
    );
  }
}

/// Draws the logo (same letters and tilt as [HalalaLogoPainter]) with dashed, empty coin spots and [falling] gold
/// coins above it, each with a hard shadow and two short motion lines. [progress] runs 0 to 1 as the coins fall
/// from higher up to where they hang.
class EmptyArtPainter extends CustomPainter {
  EmptyArtPainter({
    required this.line,
    required this.fill,
    required this.spot,
    required this.coin,
    required this.falling,
    this.progress = 1,
  });

  final Color line;
  final Color fill;
  final Color spot;
  final Color coin;
  final int falling;
  final double progress;

  // The logo's own viewBox, extended upwards to leave room for the falling coins.
  static const viewX = -30.8, viewY = -1230.0, viewW = 1719.0, viewH = 1447.0;
  static const _pivot = Offset(828.6, -321.2);
  static const _shadow = Offset(34.2, 46.6);
  static const _stroke = 46.6;
  static const _spotRadius = 62.0;
  static const _spots = [Offset(402.9, -650.0), Offset(292.6, -610.0)];

  // Where the falling coins hang (logo units, before the tilt), and how far above that they start.
  static const _hang = [Offset(462.9, -980.0), Offset(172.6, -1090.0)];
  static const _fallRadius = 95.0;
  static const _fallFrom = 260.0;

  static final Path _letters = parseSvgPath(lettersPath);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / viewW;
    canvas
      ..save()
      ..scale(s)
      ..translate(-viewX, -viewY)
      ..translate(_pivot.dx, _pivot.dy)
      ..rotate(-8 * math.pi / 180)
      ..translate(-_pivot.dx, -_pivot.dy);
    final solid = Paint()..color = line;
    final outline = Paint()
      ..color = line
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..strokeJoin = StrokeJoin.round;

    // Letters: shadow, outline, fill (as in the logo).
    canvas
      ..drawPath(_letters.shift(_shadow), solid)
      ..drawPath(_letters.shift(_shadow), outline)
      ..drawPath(_letters, solid)
      ..drawPath(_letters, outline)
      ..drawPath(_letters, Paint()..color = fill);

    // Empty coin spots: page-coloured discs with a dashed ring.
    final dash = Paint()
      ..color = line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 20
      ..strokeCap = StrokeCap.round;
    for (final c in _spots) {
      canvas.drawCircle(c, _spotRadius, Paint()..color = spot);
      const n = 6;
      const sweep = 2 * math.pi / n;
      for (var i = 0; i < n; i++) {
        canvas.drawArc(
          Rect.fromCircle(center: c, radius: _spotRadius),
          i * sweep,
          sweep * 0.55,
          false,
          dash,
        );
      }
    }

    // Falling coins with a hard shadow and motion lines above them.
    final lines = Paint()
      ..color = line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 22
      ..strokeCap = StrokeCap.round;
    final rim = Paint()
      ..color = line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 34;
    for (var i = 0; i < falling.clamp(0, _hang.length); i++) {
      // The second coin starts a little later, so they do not move as one.
      final p = i == 0 ? progress : ((progress - 0.15) / 0.85).clamp(0.0, 1.0);
      final c = _hang[i] - Offset(0, _fallFrom * (1 - p));
      canvas
        ..drawLine(
          c + const Offset(-40, -170),
          c + const Offset(-40, -110),
          lines,
        )
        ..drawLine(
          c + const Offset(40, -190),
          c + const Offset(40, -130),
          lines,
        )
        ..drawCircle(c + const Offset(30, 40), _fallRadius, solid)
        ..drawCircle(c, _fallRadius, Paint()..color = coin)
        ..drawCircle(c, _fallRadius, rim);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(EmptyArtPainter old) =>
      old.line != line ||
      old.fill != fill ||
      old.spot != spot ||
      old.coin != coin ||
      old.falling != falling ||
      old.progress != progress;
}
