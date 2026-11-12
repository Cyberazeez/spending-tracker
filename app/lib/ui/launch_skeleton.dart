import 'package:flutter/cupertino.dart';

import 'halala_logo.dart';
import 'skeleton.dart';

/// What the person sees while Face ID is asked for at app start (and the lock screen): the app's look as grey
/// blocks with the logo on top, instead of a blank page.
class LaunchSkeleton extends StatelessWidget {
  const LaunchSkeleton({super.key, this.child});

  /// Optional content over the blocks (the lock screen's scrim and Unlock card); the logo stays on top of it.
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        CustomScrollView(
          physics: const NeverScrollableScrollPhysics(),
          slivers: [
            // Room for the logo (24 + 94 pt) under the status bar.
            SliverToBoxAdapter(
              child: SizedBox(height: MediaQuery.paddingOf(context).top + 136),
            ),
            const SkeletonSliver(heights: [190, 150, 210, 160]),
          ],
        ),
        ?child,
        SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 24),
              child: const HalalaLogo(width: 150),
            ),
          ),
        ),
      ],
    );
  }
}
