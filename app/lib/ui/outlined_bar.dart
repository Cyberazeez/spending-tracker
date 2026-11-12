import 'package:flutter/cupertino.dart';

import 'grow_in.dart';
import 'tokens.dart';

/// A progress bar in the outlined look: track in [AppTokens.bar], a 2 pt line outline, and a fill from the
/// leading edge that ends in a 2 pt line (so a light fill still reads against the track).
class OutlinedBar extends StatelessWidget {
  const OutlinedBar({
    super.key,
    required this.fraction,
    required this.fill,
    this.height = 12,
    this.track,
    this.fillKey,
  });

  /// 0 to 1; values outside are clamped.
  final double fraction;
  final Color fill;
  final double height;

  /// Track colour; [AppTokens.bar] when null.
  final Color? track;
  final Key? fillKey;

  @override
  Widget build(BuildContext context) {
    final share = fraction.isNaN ? 0.0 : fraction.clamp(0.0, 1.0);
    final line = AppTokens.line.resolveFrom(context);
    return Container(
      // Full width: inside a start-aligned column the track would otherwise shrink to the fill.
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: track ?? AppTokens.bar.resolveFrom(context),
        borderRadius: BorderRadius.circular(height / 2),
        border: Border.all(color: line, width: AppTokens.outlineThin),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(height / 2 - AppTokens.outlineThin),
        // Grows from empty each time its screen comes into view, and moves to a new value when it changes.
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: share),
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 600),
          curve: Curves.easeOutCubic,
          builder: (_, f, _) => GrowIn(
            builder: (_, g) => FractionallySizedBox(
              alignment: AlignmentDirectional.centerStart,
              heightFactor: 1,
              widthFactor: (f * g).clamp(0.0, 1.0),
              child: DecoratedBox(
                key: fillKey,
                decoration: BoxDecoration(
                  color: fill,
                  border: share > 0 && share < 1
                      ? BorderDirectional(
                          end: BorderSide(
                            color: line,
                            width: AppTokens.outlineThin,
                          ),
                        )
                      : null,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
