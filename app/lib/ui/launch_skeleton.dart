import 'package:flutter/cupertino.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'skeleton.dart';
import 'tokens.dart';

/// What the person sees while Face ID is asked for at app start (and the lock screen): the app's look as grey
/// blocks with the logo on top, instead of a blank page.
class LaunchSkeleton extends StatelessWidget {
  const LaunchSkeleton({super.key, this.child});

  /// Optional content over the blocks (the Unlock button).
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final accent = AppTokens.accent.resolveFrom(context);
    return Stack(
      children: [
        CustomScrollView(
          physics: const NeverScrollableScrollPhysics(),
          slivers: [
            const SliverToBoxAdapter(child: SizedBox(height: 120)),
            const SkeletonSliver(heights: [190, 150, 210, 160]),
          ],
        ),
        SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 32),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: SizedBox(
                  width: 64,
                  height: 64,
                  child: Icon(LucideIcons.wallet, size: 30, color: accent),
                ),
              ),
            ),
          ),
        ),
        ?child,
      ],
    );
  }
}
