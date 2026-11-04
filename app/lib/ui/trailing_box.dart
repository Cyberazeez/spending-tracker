import 'package:flutter/widgets.dart';

/// An amount at the end of a row: it takes the width it needs (up to 45% of the screen, then it shrinks with a
/// FittedBox inside) and the title beside it gets all the rest. A plain `Flexible` would split the row in two halves
/// and leave the amount floating in the middle.
class TrailingBox extends StatelessWidget {
  const TrailingBox({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: BoxConstraints(
      maxWidth: MediaQuery.sizeOf(context).width * 0.45,
    ),
    child: child,
  );
}
