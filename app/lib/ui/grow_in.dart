import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/widgets.dart';

import 'sliding_pill.dart' show SmallBackCurve;

/// Grows a progress shape (the Home budget ring, the Bills bar) from empty to its value with a small overshoot,
/// when it first appears and again each time its screen comes back into view (switching to its tab, coming back
/// from a page opened on top of it). [builder] gets 0 to about 1.03, settling at exactly 1. With Reduce Motion it is
/// shown at its value straight away.
class GrowIn extends StatefulWidget {
  const GrowIn({
    super.key,
    required this.builder,
    this.duration = const Duration(milliseconds: 900),
  });

  final Widget Function(BuildContext context, double t) builder;
  final Duration duration;

  @override
  State<GrowIn> createState() => _GrowInState();
}

class _GrowInState extends State<GrowIn> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  late final Animation<double> _t = CurvedAnimation(
    parent: _c,
    curve: const SmallBackCurve(),
  );
  ValueListenable<TickerModeData>? _shown;
  bool _wasShown = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final shown = TickerMode.getValuesNotifier(context);
    if (shown != _shown) {
      _shown?.removeListener(_onShown);
      _shown = shown..addListener(_onShown);
      _onShown();
    }
  }

  /// Plays when the screen goes from hidden (or not yet built) to shown.
  void _onShown() {
    final now = _shown?.value.enabled ?? false;
    final appeared = now && !_wasShown;
    _wasShown = now;
    if (!mounted || !appeared) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.value = 1;
    } else {
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _shown?.removeListener(_onShown);
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _t,
    builder: (context, _) => widget.builder(context, _t.value),
  );
}
