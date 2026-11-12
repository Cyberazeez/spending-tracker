import 'package:flutter/gestures.dart' show kTouchSlop;
import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

/// Builds the pressable box. [depth] is how far it has sunk into its hard shadow: 0 at rest, 1 fully pressed, a
/// little below 0 while it springs back. Draw the shadow with `offset * (1 - depth)` so the box and its shadow meet
/// when pressed.
typedef PressBuilder = Widget Function(BuildContext context, double depth);

/// Makes a button or card with a hard shadow press into that shadow while a finger is on it and spring back when it
/// is lifted. It only watches the pointer: the tap itself is still handled (and fires) exactly as before, by the
/// button or gesture detector around it. A press that turns into a scroll or drag lets go at once.
///
/// With Reduce Motion on, nothing moves: the box fades to 60% while pressed instead.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.offset,
    required this.builder,
    this.enabled = true,
  });

  /// The box's hard-shadow offset: how far it moves when fully pressed.
  final Offset offset;
  final PressBuilder builder;

  /// False for a disabled button: it does not move.
  final bool enabled;

  /// How far a press may travel before it counts as a scroll and lets go.
  static const slop = kTouchSlop;

  @override
  State<Pressable> createState() => _PressableState();
}

/// The spring that brings a pressed box back: quick, with a small bounce past its rest position.
const pressSpring = SpringDescription(mass: 1, stiffness: 520, damping: 22);

class _PressableState extends State<Pressable>
    with SingleTickerProviderStateMixin {
  late final AnimationController _depth = AnimationController.unbounded(
    vsync: this,
  );
  Offset? _start;
  bool _held = false;

  bool get _reduce => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  @override
  void dispose() {
    _depth.dispose();
    super.dispose();
  }

  void _down(PointerDownEvent e) {
    if (!widget.enabled) return;
    _start = e.position;
    _held = true;
    _depth.animateTo(
      1,
      duration: Duration(milliseconds: _reduce ? 90 : 70),
      curve: Curves.easeOut,
    );
  }

  void _move(PointerMoveEvent e) {
    final start = _start;
    if (start != null && (e.position - start).distance > Pressable.slop) {
      _up(); // the finger is scrolling or dragging, not pressing
    }
  }

  Future<void> _up([PointerEvent? _]) async {
    if (!_held) return;
    _held = false;
    _start = null;
    // A very quick tap still shows the press: finish going down first.
    if (_depth.value < 1 && _depth.isAnimating) {
      await _depth.animateTo(1, duration: const Duration(milliseconds: 40));
      if (!mounted || _held) return;
    }
    if (_reduce) {
      await _depth.animateTo(
        0,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
      );
      return;
    }
    await _depth.animateWith(
      SpringSimulation(pressSpring, _depth.value, 0, 0, snapToEnd: true),
    );
  }

  @override
  void didUpdateWidget(Pressable old) {
    super.didUpdateWidget(old);
    if (!widget.enabled && old.enabled) {
      _held = false;
      _depth.value = 0;
    }
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: _down,
    onPointerMove: _move,
    onPointerUp: _up,
    onPointerCancel: _up,
    child: AnimatedBuilder(
      animation: _depth,
      builder: (context, _) {
        final d = _depth.value.clamp(-0.2, 1.0);
        if (_reduce) {
          return Opacity(
            opacity: 1 - 0.4 * d.clamp(0.0, 1.0),
            child: widget.builder(context, 0),
          );
        }
        return Transform.translate(
          offset: widget.offset * d,
          child: widget.builder(context, d),
        );
      },
    ),
  );
}
