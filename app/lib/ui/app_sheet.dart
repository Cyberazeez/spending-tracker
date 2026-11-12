import 'package:flutter/cupertino.dart';

import 'tokens.dart';

/// Opens a bottom sheet the app's way: like [showCupertinoModalPopup] (root navigator, dimmed barrier that closes it
/// on tap), but the sheet rises with a small overshoot and settles. With Reduce Motion on it fades in instead.
Future<T?> showAppSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) => Navigator.of(context, rootNavigator: true).push(
  AppSheetRoute<T>(
    builder: builder,
    barrierColor: CupertinoDynamicColor.resolve(
      kCupertinoModalBarrierColor,
      context,
    ),
  ),
);

/// The same route as the system's [CupertinoModalPopupRoute] (barrier, labels, elevated level), with its own rise.
/// It is a [PopupRoute] of its own because the system one is driven by a spring, which stops at the end position
/// and cannot overshoot.
class AppSheetRoute<T> extends PopupRoute<T> {
  AppSheetRoute({required this.builder, required this.barrierColor});

  final WidgetBuilder builder;

  /// Rise time; close to the system sheet (335 ms).
  static const rise = Duration(milliseconds: 340);

  @override
  final Color? barrierColor;

  @override
  bool get barrierDismissible => true;

  @override
  bool get semanticsDismissible => false;

  @override
  String get barrierLabel => 'Dismiss';

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => CupertinoUserInterfaceLevel(
    data: CupertinoUserInterfaceLevelData.elevated,
    child: DisplayFeatureSubScreen(child: Builder(builder: builder)),
  );

  CurvedAnimation? _rise;

  @override
  void dispose() {
    _rise?.dispose();
    super.dispose();
  }

  @override
  Duration get transitionDuration => rise;

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 240);

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return Align(
        alignment: Alignment.bottomCenter,
        child: FadeTransition(opacity: animation, child: child),
      );
    }
    // One curved animation for the route's life: a fresh one each frame would switch to the closing curve
    // mid-rise and make the sheet jump when it is closed while still rising.
    final rise = _rise ??= CurvedAnimation(
      parent: animation,
      curve: const SheetRiseCurve(),
      reverseCurve: Curves.easeInCubic,
    );
    // While it overshoots, the sheet's bottom edge lifts off the screen edge: a strip of the sheet colour under it
    // keeps the gap filled.
    final fill = AppTokens.bg.resolveFrom(context);
    return Align(
      alignment: Alignment.bottomCenter,
      child: AnimatedBuilder(
        animation: rise,
        builder: (context, child) => FractionalTranslation(
          translation: Offset(0, 1 - rise.value),
          child: child,
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            child,
            Positioned(
              left: 0,
              right: 0,
              bottom: -60,
              height: 60,
              child: ColoredBox(key: const ValueKey('sheet-fill'), color: fill),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ease-out that rises about 3% past the end and settles back.
class SheetRiseCurve extends Curve {
  const SheetRiseCurve();

  @override
  double transformInternal(double t) {
    const s = 0.9;
    final u = t - 1;
    return u * u * ((s + 1) * u + s) + 1;
  }
}
