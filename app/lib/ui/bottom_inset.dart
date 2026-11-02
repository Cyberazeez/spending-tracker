import 'package:flutter/cupertino.dart';

/// Empty space at the end of a [CustomScrollView] equal to the bottom inset the tab scaffold reports (the tab bar),
/// so the last rows can be scrolled clear of the bar instead of hiding underneath it.
/// (A plain ListView applies this by itself; a CustomScrollView does not.)
class BottomInset extends StatelessWidget {
  const BottomInset({super.key});

  @override
  Widget build(BuildContext context) => SliverToBoxAdapter(
    child: SizedBox(height: MediaQuery.paddingOf(context).bottom + 16),
  );
}
