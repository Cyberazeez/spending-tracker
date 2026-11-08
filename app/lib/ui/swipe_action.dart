import 'package:flutter/cupertino.dart';
import 'package:flutter/semantics.dart';

import 'tokens.dart';

/// A row that slides toward its leading side to show one action button at the end (iOS style): swipe from right to
/// left in English, left to right in Arabic. Tapping the row while the button is out closes it again. The action
/// is also offered to VoiceOver as a custom action.
class SwipeAction extends StatefulWidget {
  const SwipeAction({
    super.key,
    required this.child,
    required this.label,
    required this.onAction,
    this.destructive = true,
  });

  final Widget child;
  final String label;
  final bool destructive;

  /// Runs when the button is tapped; the row closes when it returns (unless the row is gone by then).
  final Future<void> Function() onAction;

  @override
  State<SwipeAction> createState() => _SwipeActionState();
}

class _SwipeActionState extends State<SwipeAction>
    with SingleTickerProviderStateMixin {
  static const _buttonWidth = 88.0;

  late final AnimationController _open = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
  );
  bool _busy = false;

  bool get _rtl => Directionality.of(context) == TextDirection.rtl;

  @override
  void dispose() {
    _open.dispose();
    super.dispose();
  }

  void _drag(DragUpdateDetails d) {
    // Movement toward the leading side opens the button, movement back closes it.
    final toward = _rtl ? d.delta.dx : -d.delta.dx;
    _open.value = (_open.value + toward / _buttonWidth).clamp(0.0, 1.0);
  }

  void _release(DragEndDetails d) {
    final v = d.velocity.pixelsPerSecond.dx * (_rtl ? 1 : -1);
    if (v > 300) {
      _open.animateTo(1);
    } else if (v < -300) {
      _open.animateTo(0);
    } else {
      _open.animateTo(_open.value > 0.5 ? 1 : 0);
    }
  }

  Future<void> _run() async {
    if (_busy) return;
    _busy = true;
    try {
      await widget.onAction();
    } finally {
      _busy = false;
      if (mounted) _open.animateTo(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sign = _rtl ? 1.0 : -1.0;
    final color = widget.destructive
        ? AppTokens.danger.resolveFrom(context)
        : AppTokens.accent.resolveFrom(context);
    return Semantics(
      customSemanticsActions: {
        CustomSemanticsAction(label: widget.label): _run,
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: _drag,
        onHorizontalDragEnd: _release,
        onTap: () {
          if (_open.value > 0) _open.animateTo(0);
        },
        child: ClipRect(
          child: Stack(
            children: [
              Positioned.fill(
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: SizedBox(
                    width: _buttonWidth,
                    height: double.infinity,
                    child: ExcludeSemantics(
                      child: CupertinoButton(
                        padding: EdgeInsets.zero,
                        borderRadius: BorderRadius.zero,
                        color: color,
                        onPressed: _run,
                        child: Text(
                          widget.label,
                          style: const TextStyle(
                            color: CupertinoColors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              AnimatedBuilder(
                animation: _open,
                builder: (context, child) => Transform.translate(
                  offset: Offset(sign * _open.value * _buttonWidth, 0),
                  child: AbsorbPointer(
                    // While the button is out the row itself is inert: a tap on it only closes.
                    absorbing: _open.value > 0.01,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppTokens.card.resolveFrom(context),
                      ),
                      child: child,
                    ),
                  ),
                ),
                child: widget.child,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
