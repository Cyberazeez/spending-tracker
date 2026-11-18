import 'package:flutter/widgets.dart';

/// Puts the keyboard away, wherever it is open.
void hideKeyboard() => FocusManager.instance.primaryFocus?.unfocus();

/// Puts the keyboard away whenever a screen or sheet opens or closes (back button, swipe back, Cancel), so it never
/// stays up over a screen that has no text field, and a closed sheet does not bring it back.
class KeyboardDismissObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      hideKeyboard();

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      hideKeyboard();

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      hideKeyboard();

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      hideKeyboard();
}

/// Tapping anywhere that is not a text field or a button puts the keyboard away (iOS has no "done" key on most
/// keyboards). Taps on fields and buttons still go to them.
class TapOutsideToDismissKeyboard extends StatelessWidget {
  const TapOutsideToDismissKeyboard({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.translucent,
    // Not a control: VoiceOver must not announce the whole screen as one unlabelled button.
    excludeFromSemantics: true,
    onTap: hideKeyboard,
    child: child,
  );
}
