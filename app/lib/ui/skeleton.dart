import 'package:flutter/cupertino.dart';

import 'tokens.dart';

/// Grey rounded placeholder blocks shown while the first data loads (no spinner).
class SkeletonSliver extends StatelessWidget {
  const SkeletonSliver({super.key, required this.heights});

  final List<double> heights;

  @override
  Widget build(BuildContext context) {
    final fill = AppTokens.card.resolveFrom(context);
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      sliver: SliverList.list(
        children: [
          for (final h in heights)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: fill,
                  borderRadius: BorderRadius.circular(AppTokens.radiusCard),
                ),
                child: SizedBox(height: h, width: double.infinity),
              ),
            ),
        ],
      ),
    );
  }
}
