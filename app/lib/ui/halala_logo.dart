import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

import 'tokens.dart';

/// The Halala logo (the word هللة with two gold coins), drawn from the path in `docs/brand/logo.svg` so it needs no
/// image package and follows the theme: outline and hard shadow in [AppTokens.line] (ink in light mode, paper in
/// dark so it stays visible on the dark page), letters in [AppTokens.accent], coins in [AppTokens.gold].
class HalalaLogo extends StatefulWidget {
  const HalalaLogo({super.key, this.width = 190, this.dropCoins = false});

  final double width;

  /// Play the coin drop once when the logo appears (launch: lock and sign-in screens): the coins hop up and fall
  /// back into place with a bounce. They never leave the picture, so the static launch image hands over without a
  /// jump. Off with Reduce Motion.
  final bool dropCoins;

  /// The logo's own word, read by VoiceOver (it is a picture of this word).
  static const semanticLabel = 'هللة';

  /// Length of the coin drop.
  static const dropDuration = Duration(milliseconds: 1100);

  @override
  State<HalalaLogo> createState() => _HalalaLogoState();
}

class _HalalaLogoState extends State<HalalaLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _drop = AnimationController(
    vsync: this,
    duration: HalalaLogo.dropDuration,
    value: 1, // at rest unless the drop plays
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.dropCoins &&
        !MediaQuery.disableAnimationsOf(context) &&
        _drop.value == 1 &&
        !_played) {
      _played = true;
      _drop.forward(from: 0);
    }
  }

  bool _played = false;

  @override
  void dispose() {
    _drop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: HalalaLogo.semanticLabel,
    child: AnimatedBuilder(
      animation: _drop,
      builder: (context, _) => CustomPaint(
        size: Size(widget.width, widget.width * _viewH / _viewW),
        painter: HalalaLogoPainter(
          line: AppTokens.line.resolveFrom(context),
          fill: AppTokens.accent.resolveFrom(context),
          coin: AppTokens.gold.resolveFrom(context),
          coinLift: [coinLift(_drop.value, 0), coinLift(_drop.value, 1)],
        ),
      ),
    ),
  );
}

/// How high (in logo units, about a third of the letters' height at most) coin [i] is at time [t] of the drop:
/// a quick hop up, then a fall with a bounce. 0 at the start and at the end. The second coin follows a moment later.
double coinLift(double t, int i) {
  const height = 300.0;
  final u = ((t - i * 0.12) / 0.88).clamp(0.0, 1.0);
  if (u <= 0 || u >= 1) return 0;
  if (u < 0.25) return height * Curves.easeOutCubic.transform(u / 0.25);
  return height * (1 - Curves.bounceOut.transform((u - 0.25) / 0.75));
}

// The SVG's viewBox, rotation and shadow offset.
const _viewX = -30.8, _viewY = -859.7, _viewW = 1719.0, _viewH = 1077.0;
const _pivot = Offset(828.6, -321.2);
const _shadow = Offset(34.2, 46.6);
const _stroke = 46.6;
const _coinRadius = 62.0;
const _coins = [Offset(402.9, -650.0), Offset(292.6, -610.0)];

class HalalaLogoPainter extends CustomPainter {
  HalalaLogoPainter({
    required this.line,
    required this.fill,
    required this.coin,
    this.coinLift = const [0, 0],
  });

  final Color line;
  final Color fill;
  final Color coin;

  /// How far each coin is lifted, in logo units.
  final List<double> coinLift;

  Offset _coin(int i) => _coins[i] - Offset(0, coinLift[i]);

  static final Path _letters = parseSvgPath(_lettersPath);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / _viewW;
    canvas
      ..save()
      ..scale(s)
      ..translate(-_viewX, -_viewY)
      ..translate(_pivot.dx, _pivot.dy)
      ..rotate(-8 * math.pi / 180)
      ..translate(-_pivot.dx, -_pivot.dy);
    final solid = Paint()..color = line;
    final outline = Paint()
      ..color = line
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..strokeJoin = StrokeJoin.round;
    void letters(Offset at) {
      final path = _letters.shift(at);
      canvas
        ..drawPath(path, solid)
        ..drawPath(path, outline);
    }

    void coinsInk(Offset at) {
      for (var i = 0; i < _coins.length; i++) {
        canvas
          ..drawCircle(_coin(i) + at, _coinRadius, solid)
          ..drawCircle(_coin(i) + at, _coinRadius, outline);
      }
    }

    // Same order as the SVG: shadow, letter outline, letter fill, coin outline, coin fill (so the coins stay on
    // top when they move).
    letters(_shadow);
    coinsInk(_shadow);
    letters(Offset.zero);
    canvas.drawPath(_letters, Paint()..color = fill);
    coinsInk(Offset.zero);
    for (var i = 0; i < _coins.length; i++) {
      canvas.drawCircle(_coin(i), _coinRadius, Paint()..color = coin);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(HalalaLogoPainter old) =>
      old.line != line ||
      old.fill != fill ||
      old.coin != coin ||
      old.coinLift[0] != coinLift[0] ||
      old.coinLift[1] != coinLift[1];
}

/// Reads the absolute M, L, Q and Z commands of an SVG path (the only ones the logo uses); a command letter may be
/// followed by several coordinate groups, as SVG allows.
Path parseSvgPath(String d) {
  final tokens = RegExp(r'[A-Za-z]|-?\d*\.?\d+')
      .allMatches(d)
      .map((m) => m[0]!)
      .toList();
  final path = Path();
  var i = 0;
  var cmd = '';
  double n() => double.parse(tokens[i++]);
  while (i < tokens.length) {
    final tok = tokens[i];
    if (RegExp(r'^[A-Za-z]$').hasMatch(tok)) {
      cmd = tok;
      i++;
      if (cmd == 'Z') {
        path.close();
        continue;
      }
    }
    switch (cmd) {
      case 'M':
        path.moveTo(n(), n());
        cmd = 'L'; // further pairs after a move are lines
      case 'L':
        path.lineTo(n(), n());
      case 'Q':
        path.quadraticBezierTo(n(), n(), n(), n());
      default:
        throw FormatException('Unsupported path command', d);
    }
  }
  return path;
}

const _lettersPath =
    'M508.8 -150 447.2 -33 423.4 -15 296.2 -1 302.3 -27Q339.9 -189 347.6 -231Q295.1 -165 260 -145Q240.2 -134 214.7 -127.5Q189.2 -121 166.2 -121Q113.2 -121 86.4 -154Q59.6 -187 66.4 -230Q75 -284 122.7 -348.5Q170.4 -413 231.5 -458Q292.7 -503 337.7 -503Q417.7 -503 451.8 -444Q486 -385 469 -278Q464.7 -257 457.2 -222Q449.6 -187 443.5 -161L505.5 -167ZM349.5 -281Q343.5 -319 312.1 -335Q280.6 -351 223.6 -351Q191.6 -351 165.2 -342Q166.5 -306 197.8 -283Q229.2 -260 271.2 -260Q314.2 -260 349.5 -281ZM764.5 -136 703 -19 679.2 -1 581.6 9Q590.2 -33 603.8 -119Q607.6 -143 608.5 -155Q581.6 -92 549.3 -40Q492.5 -22 423.4 -15L505.5 -167Q563.2 -172 611.5 -186Q616.4 -255 611.6 -328.8Q608.5 -413.8 597.4 -476.2Q629.8 -528.8 669.5 -577.5Q709.2 -626.2 741.6 -653.8Q746.8 -623.8 740.6 -524.4Q734.3 -425 722 -347.5Q711.2 -279 699.7 -225.5Q688.2 -172 680 -145L761.2 -153ZM1020.3 -122 958.8 -5 934.9 13 837.4 23Q846 -19 859.6 -105Q863.4 -129 864.3 -141Q837.4 -78 805.1 -26Q748.3 -8 679.2 -1L761.2 -153Q819 -158 867.2 -172Q872.2 -241 866.8 -311.2Q863.8 -396.2 852.7 -458.8Q885 -511.2 924.7 -560Q964.4 -608.8 996.8 -636.2Q1002 -606.2 995.8 -506.9Q989.5 -407.5 977.3 -330Q967 -265 955.5 -211.5Q944 -158 935.7 -131L1017 -139ZM1553.5 -344Q1541.9 -271 1516 -218Q1490.1 -165 1458.3 -122Q1432.8 -100 1385.6 -76.5Q1338.4 -53 1287.4 -37.5Q1236.5 -22 1201.5 -22Q1172.5 -22 1144.1 -32Q1061 0 934.9 13L1017 -139L1074 -145Q1073.9 -157 1075 -164Q1103.4 -255 1164.3 -330Q1225.1 -405 1295.4 -432Q1326.5 -420 1344.2 -377Q1361.9 -334 1354 -284Q1345.9 -233 1310.4 -179Q1393.3 -191 1443.9 -208Q1453.7 -282 1434.4 -350Q1415.2 -418 1374.9 -460Q1334.5 -502 1284.5 -502Q1257.5 -502 1225.1 -486.5Q1192.6 -471 1144.4 -432L1129.5 -445Q1169.4 -495 1220.1 -534Q1270.8 -573 1320.1 -594Q1369.4 -615 1406.4 -615Q1467.4 -615 1503.8 -573.5Q1540.3 -532 1551.9 -469.5Q1563.5 -407 1553.5 -344ZM1221.9 -315 1230.4 -318ZM1153.9 -258Q1152.6 -231 1173.8 -207Q1195 -183 1228.9 -176Q1238 -196 1240.7 -213Q1245.8 -245 1232.3 -270Q1218.7 -295 1195.7 -301Q1162.9 -277 1153.9 -258Z';
