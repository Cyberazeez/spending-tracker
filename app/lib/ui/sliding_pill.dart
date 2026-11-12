import 'package:flutter/widgets.dart';

/// The selected-item pill of a pill bar (tab bar, segmented control), drawn under the items as one layer: it slides
/// to the selected slot with a small overshoot (none into the first or last slot, where it would poke past the bar's
/// rounded end). With Reduce Motion it fades out under the old slot and in under the new one.
/// Put it in a [Stack] under a [Row] of [count] equal [Expanded] slots.
class SlidingPill extends StatelessWidget {
  const SlidingPill({
    super.key,
    required this.count,
    required this.index,
    required this.pill,
  });

  final int count;
  final int index;
  final Widget pill;

  static const duration = Duration(milliseconds: 320);

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return Positioned.fill(
        child: Row(
          children: [
            for (var i = 0; i < count; i++)
              Expanded(
                child: AnimatedOpacity(
                  opacity: i == index ? 1 : 0,
                  duration: const Duration(milliseconds: 160),
                  child: pill,
                ),
              ),
          ],
        ),
      );
    }
    if (count < 1 || index < 0 || index >= count) {
      return const SizedBox.shrink();
    }
    return Positioned.fill(
      child: AnimatedAlign(
        key: const ValueKey('sliding-pill'),
        alignment: AlignmentDirectional(
          count == 1 ? 0 : -1 + 2 * index / (count - 1),
          0,
        ),
        duration: duration,
        curve: index == 0 || index == count - 1
            ? Curves.easeOutCubic
            : const SmallBackCurve(),
        child: FractionallySizedBox(
          widthFactor: 1 / count,
          heightFactor: 1,
          child: pill,
        ),
      ),
    );
  }
}

/// Ease-out with a small overshoot (about 3% of the distance) before it settles.
class SmallBackCurve extends Curve {
  const SmallBackCurve();

  @override
  double transformInternal(double t) {
    const s = 0.9;
    final u = t - 1;
    return u * u * ((s + 1) * u + s) + 1;
  }
}
