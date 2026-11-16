import 'package:flutter/cupertino.dart';

/// Google's four-colour "G" mark, drawn from the official artwork (256 x 262 units). Never recoloured or redrawn
/// (Google's sign-in branding rules).
class GoogleLogo extends StatelessWidget {
  const GoogleLogo({super.key, this.size = 20});
  final double size;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size(size * 256 / 262, size),
    painter: const _GoogleLogoPainter(),
  );
}

class _GoogleLogoPainter extends CustomPainter {
  const _GoogleLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..save()
      ..scale(size.height / 262);
    canvas.drawPath(
      Path()
        ..moveTo(255.878, 133.451)
        ..cubicTo(255.878, 122.717, 255.007, 114.884, 253.122, 106.761)
        ..lineTo(130.55, 106.761)
        ..lineTo(130.55, 155.209)
        ..lineTo(202.497, 155.209)
        ..cubicTo(201.047, 167.249, 193.214, 185.381, 175.807, 197.565)
        ..lineTo(175.563, 199.187)
        ..lineTo(214.318, 229.21)
        ..lineTo(217.003, 229.478)
        ..cubicTo(241.662, 206.704, 255.878, 173.196, 255.878, 133.451),
      Paint()..color = const Color(0xFF4285F4),
    );
    canvas.drawPath(
      Path()
        ..moveTo(130.55, 261.1)
        ..cubicTo(165.798, 261.1, 195.389, 249.495, 217.003, 229.478)
        ..lineTo(175.807, 197.565)
        ..cubicTo(164.783, 205.253, 149.987, 210.62, 130.55, 210.62)
        ..cubicTo(96.027, 210.62, 66.726, 187.847, 56.281, 156.37)
        ..lineTo(54.75, 156.5)
        ..lineTo(14.452, 187.687)
        ..lineTo(13.925, 189.152)
        ..cubicTo(35.393, 231.798, 79.49, 261.1, 130.55, 261.1),
      Paint()..color = const Color(0xFF34A853),
    );
    canvas.drawPath(
      Path()
        ..moveTo(56.281, 156.37)
        ..cubicTo(53.525, 148.247, 51.93, 139.543, 51.93, 130.55)
        ..cubicTo(51.93, 121.556, 53.525, 112.853, 56.136, 104.73)
        ..lineTo(56.063, 103)
        ..lineTo(15.26, 71.312)
        ..lineTo(13.925, 71.947)
        ..cubicTo(5.077, 89.644, 0, 109.517, 0, 130.55)
        ..cubicTo(0, 151.583, 5.077, 171.455, 13.925, 189.152)
        ..close(),
      Paint()..color = const Color(0xFFFBBC05),
    );
    canvas.drawPath(
      Path()
        ..moveTo(130.55, 50.479)
        ..cubicTo(155.064, 50.479, 171.6, 61.068, 181.029, 69.917)
        ..lineTo(217.873, 33.943)
        ..cubicTo(195.245, 12.91, 165.798, 0, 130.55, 0)
        ..cubicTo(79.49, 0, 35.393, 29.301, 13.925, 71.947)
        ..lineTo(56.136, 104.73)
        ..cubicTo(66.726, 73.253, 96.027, 50.479, 130.55, 50.479),
      Paint()..color = const Color(0xFFEB4335),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GoogleLogoPainter old) => false;
}

/// The Sign in with Google button in Google's own light and dark styles: white with a grey outline, or near-black
/// with a grey outline, the "G" mark on the left of the label. Same height and pill shape as the Apple button.
class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final dark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: label,
      excludeSemantics: true,
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: const Size(44, 52),
        onPressed: onPressed,
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: dark ? const Color(0xFF131314) : const Color(0xFFFFFFFF),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: dark ? const Color(0xFF8E918F) : const Color(0xFF747775),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const GoogleLogo(),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: dark
                        ? const Color(0xFFE3E3E3)
                        : const Color(0xFF1F1F1F),
                    fontSize: 19,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
